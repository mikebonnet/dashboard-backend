# Cron script to clone the necessary git repos

library(pins)
library(tidyverse)
library(here)
library(furrr)

setwd(here())

board_register_local(name = 'conscious_lang', cache = config::get('cachedir'))

repos <- pin_get('cl_results', board = 'conscious_lang') %>%
  filter(pull == 0) %>%
  select(url, org, prefix, repo, branch, name)

count_words <- function(org, name, regx) {
  # Search path for this repo
  path = file.path(config::get('clonedir'), org, name)

  # This is very ugly, but ag returns exit 1 on match-not-found
  suppressWarnings(
    system2('ag',c('-c', regx, path), stdout = TRUE, stderr = FALSE)
  ) -> res

  # Ag2 vs Ag1
  if (length(res) > 0 && str_detect(res[1],':')) {
    #AG1 returns paths too
    res %>%
      str_extract(':[0-9]*$') %>%
      str_remove(':') -> res
  }

  res %>%
    as.integer() %>%
    sum() %>%
    return()
}

# Count words in clone
plan(multiprocess, workers=2)
repos %>%
  mutate(blacklist = future_map2_int(org, name, count_words, 'black[-_]?list', .progress = TRUE),
         whitelist = future_map2_int(org, name, count_words, 'white[-_]?list', .progress = TRUE),
         master    = future_map2_int(org, name, count_words, 'master',         .progress = TRUE),
         slave     = future_map2_int(org, name, count_words, 'slave',          .progress = TRUE)
  ) -> repos

repos %>%
  pin(name='cl_results', board = 'conscious_lang')
