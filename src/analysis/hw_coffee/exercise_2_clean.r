# Cleans info for beef

library(readxl)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(readr)
library(stringr)
library(haven)
#library(felm)

#######################
#######################
mode_pc = 1 ###########
#######################
#######################

# Input
filename_main       <- "data.csv"      # p (hacienda and 4th) and q at firm month level
filename_maino      <- "main_data_coffee.csv"      # p (hacienda and 4th) and q at firm month level

if (mode_pc==0) {
  source("project_paths.R")
  args = strtoi(commandArgs(trailingOnly=TRUE))
  # Input
  filepath_main  <- paste(PATH_IN_DATA_COFFEE, filename_main, sep="/") 
  filepath_maino <- paste(PATH_OUT_DATA_COFFEE, filename_maino, sep="/") 
  
} else {
  
  type_system <- Sys.info()["sysname"]
  
  if (type_system=="Linux"){
    main_dir = "/home/josem/Documents/projects/"
    set_config(config(ssl_verifypeer = 0L))
  }
  else{
    main_dir <- "C:/Users/josem/Documents"
  }
  
  dir_source_data     <- paste(main_dir, "mae_io/src/original_data/data_hw_coffee/", sep="/")
  dir_source_analysis <- paste(main_dir, "mae_io/bld/out/analysis/coffee/", sep="/")
  #dir_source          <- paste(main_dir, "coffee_collusion/src/original_data/", sep="/")
  #dir_source_figures  <- paste(main_dir, "coffee_collusion/bld/out/figures/", sep="/")
  
  # Inputs
  filepath_main       <- paste(dir_source_data, filename_main,sep="") 
  filepath_maino      <- paste(dir_source_analysis, filename_maino,sep="") 
  
  
}


# Loads data
data <- read_delim(filepath_main, delim = ",")

data <- data %>%
  filter(dummy_yc == 1 & export_dummy == 1)

#data$dummy_turkey = 0
#data$dummy_turkey[data$kg_net_turkey>0] = 1

datashort <- data %>%
  select(year,
         id, qe_yc, price_y,
         costs_y_export, importGDP, teaPrices_y)

datashort %>%
  write_csv(path = filepath_maino)

datalong <- data %>%
  select(year, country,
         id, qe_yc, price_y,
         costs_y_export, importGDP, teaPrices_y)

datashortend <- datalong %>%
  group_by(year) %>%
  summarise( qe_y = sum(qe_yc), teaPrices_y = first(teaPrices_y), importGDP = first(importGDP),
             costs_y_export = first(costs_y_export), price_y = first(price_y)  )

r1 = felm( qe_y ~ importGDP + teaPrices_y | 0 | (price_y ~ costs_y_export), data = datashortend )

r1fitted = r1$c.fitted.values
datashortend$qe_y_fitted    = r1fitted
datashortend$price_y_fitted = datashortend$qe_y/r1$coefficients[4,1] - r1$coefficients[1,1]/r1$coefficients[4,1] - 
                              datashortend$importGDP*r1$coefficients[2,1]/r1$coefficients[4,1] - 
                              datashortend$teaPrices_y*r1$coefficients[3,1]/r1$coefficients[4,1]                             


plot(datashortend$year,datashortend$price_y,type="l",col="red")
lines(datashortend$year,datashortend$price_y_fitted,col="green")

#aaa = datalong %>%
#  group_by(country, id) %>%
#  summarise( q = sum(qe_yc)  ) 

# P: p_average_butcher_cs
# Q: domestic_hook_csh
# Y: uy_gdp_percapita
# Z: p_lamb_hook, p_pigs_hook
# W: p_average_hook_csh

################################################################################
################################################################################

#datashort %>%
#  write_csv(path = filepath_maino)
