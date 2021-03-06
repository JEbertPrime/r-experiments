library(raster)
library(tidyverse)
library(stringr)
library(lubridate)
library(sf)
library(rnaturalearth)
library(scales)
library(viridis)
library(fields)
library(animation)
library(here)

dl_snowfall <- function(x, dest = getwd()) {
  base_url <- sprintf("http://www.nohrsc.noaa.gov/snowfall/data/%s/",
                      format(x, "%Y%m"))
  f <- sprintf("sfav2_CONUS_2017093012_to_%s12.tif", format(x, "%Y%m%d"))
  f_dest <- file.path(dest, f)
  download.file(file.path(base_url, f), f_dest, mode="wb")
  return(f_dest)
}
# download files
f_snowfall <- seq(ymd("2017-10-04"), ymd("2018-03-25"), by = 1) %>% 
  map_chr(dl_snowfall, dest = here("_source/data/snowfall/"))
# stack and transform
r_snowfall <- stack(f_snowfall)
NAvalue(r_snowfall) <- -99999
# clean up layer names
layer_dates <- names(r_snowfall) %>% 
  str_extract("(?<=to_)[0-9]{8}") %>% 
  ymd()
names(r_snowfall) <- paste0("snowfall_", format(layer_dates, "%Y%m%d"))
# transform and save
albers <- paste("+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=37.5 +lon_0=-96",
                "+x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs")
r_file <- format(today() - 1, "%Y%m%d") %>% 
  sprintf("snowfall_to_%s.grd", .) %>% 
  here("_source/data/snowfall/", .)
r_snowfall <- projectRaster(2.54 * r_snowfall, crs = albers, filename = r_file, 
                            overwrite = TRUE)

r <- r_snowfall[[nlayers(r_snowfall)]]
r[r < 0] <- 0
slope <- terrain(4000 * r, opt = "slope")
aspect <- terrain(4000 * r, opt = "aspect")
hill <- hillShade(slope, aspect, angle = 40, azimuth = 315)
# us border to set plot area
states <- ne_states(iso_a2 = "US", returnclass = "sf") %>% 
  filter(!postal %in% c("HI", "AK")) %>% 
  st_transform(crs = projection(r)) %>% 
  st_union()
# plot
# colors and legends
grey_pal <- alpha(grey(0:100 / 100), seq(-1, 1, length = 101)^2)
col_pal <- viridis(100, alpha = 0.6) %>% rev()
rng <- cellStats(r, range) %>% sqrt()
brks <- seq(rng[1], rng[2], length.out = length(col_pal) + 1)
lbls <- data_frame(at = seq(rng[1], rng[2], length.out = 8)) %>% 
  mutate(lbl = at^2,
         lbl = if_else(lbl < 1000, 10 * round(lbl / 10), 
                       100 * round(lbl / 100)),
         lbl = if_else(lbl < 100, paste(lbl, "cm"),
                       paste(round(lbl / 100, 2), "m")))
plot(states, border = "black", col = NA)
# hillshade 
plot(hill, col = grey(0:100 / 100), maxpixels = ncell(r), legend = FALSE, 
     axes = FALSE, box = FALSE, add = TRUE)
# color
plot(sqrt(r), col = col_pal, breaks = brks, maxpixels = ncell(r), 
     legend = FALSE, add = TRUE)
# legend
image.plot(sqrt(r),
           col = col_pal, breaks = brks,
           zlim = rng,
           smallplot = c(0.92, 0.93, 0.15, 0.85),
           legend.only = TRUE, legend.shrink = 1, legend.width = 5,
           axis.args = list(at = lbls$at, labels = lbls$lbl,
                            fg = "white", col.axis = "white",
                            cex.axis = 1, lwd.ticks = 1),
           legend.args = list(text = "Cumulative snowfall",
                              col = "white", side = 2,
                              cex = 1, line = 0.2))
# colors and legends
rng <- c(0, cellStats(r_snowfall, max) %>% max()) %>% sqrt()
brks <- seq(rng[1], rng[2], length.out = length(col_pal) + 1)
lbls <- data_frame(at = seq(rng[1], rng[2], length.out = 8)) %>% 
  mutate(lbl = at^2,
         lbl = if_else(lbl < 1000, 10 * round(lbl / 10), 
                       100 * round(lbl / 100)),
         lbl = if_else(lbl < 100, paste(lbl, "cm"),
                       paste(round(lbl / 100, 2), "m")))
# loop over layers
for (i in 1:nlayers(r_snowfall)) {
  r <- r_snowfall[[i]]
  r[r < 0] <- 0
  slope <- terrain(4000 * r, opt = "slope")
  aspect <- terrain(4000 * r, opt = "aspect")
  hill <- hillShade(slope, aspect, angle = 40, azimuth = 315)
  
  here("_source", "data", "snowfall", paste0(names(r_snowfall)[i], ".png")) %>% 
    png(width = 2000, height = 1300, res = 400, pointsize = 8)
  par(mar = c(0, 0, 0, 1.75), bg = "grey20", lwd = 0.1)
  plot(states, border = NA, col = NA)
  # hillshade 
  plot(hill, col = grey(0:100 / 100), maxpixels = ncell(r), legend = FALSE, 
       axes = FALSE, box = FALSE, add = TRUE)
  # color
  plot(sqrt(r), col = col_pal, breaks = brks, maxpixels = ncell(r), 
       legend = FALSE, add = TRUE)
  # legend
  image.plot(sqrt(r),
             col = col_pal, breaks = brks,
             zlim = rng,
             smallplot = c(0.93, 0.945, 0.15, 0.85),
             legend.only = TRUE, legend.shrink = 1, 
             axis.args = list(at = lbls$at, labels = lbls$lbl,
                              fg = "white", col.axis = "white", 
                              tck = -0.5, hadj = 0.4, lwd = NA,
                              cex.axis = 0.6, lwd.ticks = 0.5),
             legend.args = list(text = "Cumulative snowfall",
                                col = "white", side = 2,
                                cex = 0.8, line = 0.1))
  # dates
  usr <- par("usr")
  xwidth <- usr[2] - usr[1]
  yheight <- usr[4] - usr[3]
  # labels
  month_pos <- seq(0.05, 1 - 0.05, length.out = 5)
  names(month_pos) <- c("Oct", "Nov", "Dec", "Jan", "Feb")
  for (j in seq_along(month_pos)) {
    text(x = usr[1] + month_pos[j] * xwidth, y = usr[3] + 0.05 * yheight, 
         labels = names(month_pos)[j], 
         cex = 0.8, col = "white")
  }
  # lines
  dt <- str_extract(names(r), "[0-9]{8}") %>% 
    ymd()
  mth <- days_in_month(dt)
  mth_idx <- which(names(month_pos) %in% names(mth))
  bar_col <- "#FDE725FF"
  for (j in 1:(length(month_pos) - 1)) {
    mth_start_x <- month_pos[j] + 0.025
    mth_end_x <- month_pos[j + 1] - 0.025
    if (j < mth_idx) {
      lines(x = usr[1] + xwidth * c(mth_start_x, mth_end_x), 
            y = c(0.05, 0.05) * yheight + usr[3],
            col = bar_col, lwd = 2)
    } else if (j > mth_idx) {
      lines(x = usr[1] + xwidth * c(mth_start_x, mth_end_x), 
            y = c(0.05, 0.05) * yheight + usr[3],
            col = "white", lwd = 2)
    } else {
      mth_pct_cmplt <- (day(dt) - 1) / mth
      mth_abs_cmplt <- (mth_end_x - mth_start_x) * mth_pct_cmplt
      brk_pt <- mth_start_x + mth_abs_cmplt
      lines(x = usr[1] + xwidth * c(brk_pt, mth_end_x), 
            y = c(0.05, 0.05) * yheight + usr[3],
            col = "white", lwd = 2)
      lines(x = usr[1] + xwidth * c(mth_start_x, brk_pt), 
            y = c(0.05, 0.05) * yheight + usr[3],
            col = bar_col, lwd = 2)
    }
  }
  dev.off()
}

frames <- here("_source", "data", "snowfall") %>% 
  list.files("png$", full.names = TRUE) %>% 
  sort()
f_animation <- here("img", "snowfall", "snowfall_to_20180112.gif")
ani.options(interval = 0.1)
im.convert(frames, "c:/Users/uhsal/OneDrive/Documents/snowfall.gif")
