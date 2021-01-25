library(tidyverse)
library(glue)
library(here)
library(googledrive)

pins::board_register_local(name = 'conscious_lang', cache = config::get('cachedir'))

d <- pins::pin_get('cl_results',board='conscious_lang')
d %>%
	mutate(date = Sys.Date()) %>%
	relocate(date,.before = url) -> d1

h1 <- tryCatch(
    {
        pins::pin_get('cl_hist',board='conscious_lang') %>%
          bind_rows(d1) %>%
          distinct(date, url, .keep_all = TRUE)
    },
    error=function(cond) {
        message('Could not load cl_hist pin, is this the first run?')
        message(cond)
        return(d1)
    }
)

h1 %>% pins::pin('cl_hist',board='conscious_lang')

if (!config::get('gdrive_history')) { quit() }

# Push h1 to GDrive as a backup

# Register to GDrive
options(
  gargle_oauth_cache = ".secrets",
  gargle_oauth_email = TRUE
)
drive_auth(email = TRUE)

# Get the backup dir for this env (or create)
backup_dir <- drive_get(glue("DataBackups/ConsciousLanguage"))
if (nrow(backup_dir) == 0) backup_dir <- drive_mkdir(glue("DataBackups/ConsciousLanguage"))

tmpfile <- tempfile()
on.exit(unlink(tmpfile))
h1 %>% write.csv(tmpfile)

drive_put(media = tmpfile, type = 'spreadsheet',
          path = 'DataBackups/ConsciousLanguage', name = 'historical_data.csv')
