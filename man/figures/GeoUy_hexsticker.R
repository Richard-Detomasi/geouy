# This script is adapted from the one that draws the logo of the geobr package,
# man/figures/geobr_hexsticker.R as it was in December 2019
# (https://github.com/ipeaGIT/geobr). What changes is what geouy needs: the
# layers, the colors, the text and the names of the files. geobr is distributed
# under the MIT license, which asks to keep the following notice in the copies
# of its code:
#
# Copyright (c) 2019, Ipea
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

library(hexSticker) # https://github.com/GuangchuangYu/hexSticker
library(ggplot2)
library(sf)
library(geouy)


# add special text font
library(sysfonts)
font_add_google(name = "Roboto", family = "Roboto")

library(extrafont)
font_import()
loadfonts(device = "win")

# Download shape files
d <- load_geouy("Departamentos", crs = 4326)
s <- load_geouy("Secciones", crs = 4326)

# Simplify geometry
sf_use_s2(F)
d_s <- st_simplify(d, preserveTopology = TRUE, dTolerance = .1)
s_s <- st_simplify(s, preserveTopology = TRUE, dTolerance = .01)

plot(d_s['depto'])
plot(d['depto'])

plot(s_s['CODSEC'])
plot(s['CODSEC'])

as.numeric(object.size(d_s)) / as.numeric(  object.size(d))
as.numeric(object.size(s_s)) / as.numeric(  object.size(s))


### Black and light blue logo ---------------

### .png
plot_a <-
        ggplot() +
        # geom_sf(data = d_s, fill = NA, size = .3, color = "#5796c905") +
        geom_sf(data = s_s, fill = NA, size = .4, color = "#4dc0d1") +
        theme_void() +
        theme(panel.grid.major = element_line(colour = "transparent")) +
        #  theme(legend.position = "none") +
        annotate("text", x = -54.7, y = -30.8, label = "geouy", color = "#4dc0d1",
                 size = 25, family = "Roboto", fontface = "bold", angle = -35) # (.png  size = 25)(.svg  size = 6)



sticker(plot_a, package = "",
        s_x = 1.03, s_y = 1, s_width = 1.5, s_height = 1.5, # ggplot image size and position
        h_fill = "black", h_color = "black", # hexagon
        url = "https://github.com/Richard-Detomasi/geouy", u_color = "#4dc0d1", u_size = 4.8,
        spotlight = T, l_height = 17,
        filename = "./man/figures/geouy_logo_a.png", dpi = 400)  # output name and resolution


### .svg
plot_a_svg <-
        ggplot() +
        # geom_sf(data = d_s, fill = NA, size = .08, color = "#5796c905") +
        geom_sf(data = s_s, fill = NA, size = .35, color = "#4dc0d1") +
        theme_void() +
        theme(panel.grid.major = element_line(colour = "transparent")) +
        #  theme(legend.position = "none") +
        annotate("text", x = -54.7, y = -30.8, label = "geouy", color = "#4dc0d1",
                 size = 6, family = "Roboto", fontface = "bold", angle = -35) # (.png  size = 25)(.svg  size = 6)



sticker(plot_a_svg, package = "",
        s_x = 1.03, s_y = 1, s_width = 1.5, s_height = 1.5, # ggplot image size and position
        h_fill = "black", h_color = "black", # hexagon
        url = "https://github.com/Richard-Detomasi/geouy", u_color = "#4dc0d1", u_size = 1.2,
        spotlight = T, l_height = 17,
        filename = "./man/figures/geouy_logo_a.svg")  # output name and resolution


### .png
plot_b <-
  ggplot() +
  # geom_sf(data = d_s, fill = NA, size = .3, color = "#5796c905") +
  geom_sf(data = s_s, fill = NA, size = .2, color = "black") +
  theme_void() +
  theme(panel.grid.major = element_line(colour = "transparent")) +
  #  theme(legend.position = "none") +
  annotate("text", x = -54.7, y = -30.8, label = "geouy", color = "black",
           size = 25, family = "Roboto", fontface = "bold", angle = -35) # (.png  size = 25)(.svg  size = 6)



sticker(plot_b, package = "",
        s_x = 1.03, s_y = 1, s_width = 1.5, s_height = 1.5, # ggplot image size and position
        h_fill = "#4dc0d1", h_color = "#4dc0d1", # hexagon
        url = "https://github.com/Richard-Detomasi/geouy", u_color = "black", u_size = 4.8,
        spotlight = T, l_height = 17,
        filename = "./man/figures/geouy_logo_b.png", dpi = 400)  # output name and resolution


### .svg
plot_b_svg <-
  ggplot() +
  # geom_sf(data = d_s, fill = NA, size = .08, color = "#5796c905") +
  geom_sf(data = s_s, fill = NA, size = .35, color = "black") +
  theme_void() +
  theme(panel.grid.major = element_line(colour = "transparent")) +
  #  theme(legend.position = "none") +
  annotate("text", x = -54.7, y = -30.8, label = "geouy", color = "black",
           size = 6, family = "Roboto", fontface = "bold", angle = -35) # (.png  size = 25)(.svg  size = 6)



sticker(plot_b_svg, package = "",
        s_x = 1.03, s_y = 1, s_width = 1.5, s_height = 1.5, # ggplot image size and position
        h_fill = "#4dc0d1", h_color = "#4dc0d1", # hexagon
        url = "https://github.com/Richard-Detomasi/geouy", u_color = "black", u_size = 1.2,
        spotlight = T, l_height = 17,
        filename = "./man/figures/geouy_logo_b.svg")  # output name and resolution

