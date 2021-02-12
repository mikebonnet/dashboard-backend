# Cron script to get the list of repos from a local config file

library(pins)
library(tidyverse)

repodata <- config::get('repos') %>%
  map(~{if (length(.x) == 1) { names(.x) <- c('url') }; .x }) %>%
  bind_rows() %>%
  rename(repo=url)

board_register_local(name='conscious_lang', cache=config::get('cachedir'))
pin(repodata, name='cl_projects', board='conscious_lang')
