# Cron script to get the list of repos from a local config file

library(pins)

repos <- config::get('repos')
repodata = data.frame(repo=repos)

board_register_local(name='conscious_lang', cache=config::get('cachedir'))
pin(repodata, name='cl_projects', board='conscious_lang')
