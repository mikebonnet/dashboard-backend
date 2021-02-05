# Cron script to clone the necessary git repos

library(pins)
library(tidyverse)
library(git2r)
library(here)
library(furrr)

setwd(here())

board_register_local(name = 'conscious_lang', cache = config::get('cachedir'))

repos <- pin_get('cl_projects', board = 'conscious_lang') %>%
  # split up the path so we can use it for things
  mutate(url   = repo,
         path  = str_split(url,'/'),
         parts = map_int(path, ~{ .x %>%
                                    unlist() %>%
                                    length() })
  ) %>%
  mutate(org  = map2_chr(path, parts, ~{ unlist(.x) %>%
                                         head(.y) %>%
                                         tail(2) %>%
                                         head(1) }),
         repo = map_chr(path, ~{ unlist(.x) %>%
                                   tail(1) })
  ) %>%
  mutate(repo = sub('\\.git$', '', repo)) %>%
  filter(!is.na(org)) %>%
  filter(!(org == '')) %>%
  select(url, org, repo)

# We need to avoid conflicts when updating git repos *and* remove dirs no
# longer listed in the spreadsheet. While we *could* do this with "git reset"
# and "git clean" and then store every cloned dir and delete others, it's
# altogether easier to delete "clones" and start again. 20Gb of bandwidth a week
# is not so bad.

clonedir <- config::get('clonedir')
# Clean the holding area
if (dir.exists(clonedir)) { unlink(clonedir, recursive = T) }

# Create necessary dirs
dir.create(clonedir)
for (dir in unique(repos$org)) {
  if (!dir.exists(file.path(clonedir, dir))) { dir.create(file.path(clonedir, dir)) }
}

# Clone the repos
clone_to_path <- function(url, path) {
  # Can't depth-1 clone with git2r
  system2('git', c('clone', '--depth', '1', '--quiet', url, path))
}
# Do it nicely, don't break the loop
safe_clone = possibly(clone_to_path, otherwise = NA)

# Clone repos, parallel
plan(multiprocess, workers=4)
repos <- repos %>%
  mutate(pull = future_map2(url,
                     file.path(clonedir, org, repo),
                     safe_clone,
                     .progress = TRUE))

# Note the failures
repos %>%
  filter(is.na(pull)) %>%
  mutate(pull = dir.exists(file.path(clonedir, org, repo))) %>%
  select(url, pull) -> failures

pin(failures,name='cl_fails', board = 'conscious_lang')
pin(repos,name='cl_results', board = 'conscious_lang')
