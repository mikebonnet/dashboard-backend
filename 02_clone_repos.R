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
         path  = str_split(url,'/')
  ) %>%
  { if ('branch' %in% names(.)) { . } else { mutate(., branch=NA) } } %>%
  { if ('org' %in% names(.)) { . } else { mutate(., org=NA) } } %>%
  { if ('name' %in% names(.)) { . } else { mutate(., name=NA) } } %>%
  mutate(prefix  = map_chr(path, ~{ unlist(.x) %>%
                                    tail(2) %>%
                                    head(1) }),
         org = ifelse(is.na(org), prefix, org),
         repo = map_chr(path, ~{ unlist(.x) %>%
                                   tail(1) }),
         repo = sub('\\.git$', '', repo),
         name = ifelse(is.na(name), repo, name)
  ) %>%
  select(url, org, prefix, repo, branch, name)

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
clone_to_path <- function(url, path, branch) {
  if (!is.na(branch)) {
    args <- c('clone', '--depth', '1', '--branch', branch, '--quiet', url, path)
  } else {
    args <- c('clone', '--depth', '1', '--quiet', url, path)
  }
  message(paste(c('Running:', 'git', args), collapse=' '))
  # Can't depth-1 clone with git2r
  system2('git', args)
}
# Do it nicely, don't break the loop
safe_clone = possibly(clone_to_path, otherwise = NA)

# Clone repos, parallel
plan(multiprocess, workers=4)
repos <- repos %>%
  mutate(pull = future_pmap(list(url, file.path(clonedir, org, name), branch),
                            safe_clone,
                            .progress = TRUE))

# Note the failures
repos %>%
  filter(is.na(pull) | pull != 0) %>%
  select(url, pull) -> failures

pin(failures,name='cl_fails', board = 'conscious_lang')
pin(repos,name='cl_results', board = 'conscious_lang')
