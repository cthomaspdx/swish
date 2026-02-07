install.packages(
  c("tidyverse", "data.table", "jsonlite"),
  repos = "https://cloud.r-project.org",
  Ncpus = parallel::detectCores()
)
