
library(showtext)
## Loading Google fonts (http://www.google.com/fonts)
# font_add_google("Gochi Hand", "gochi")
font_add_google("Open Sans")
## Automatically use showtext to render text for future devices
showtext_auto()
library(magick)

library(hexSticker)

img.n <- image_read("C:/CodigoR/photoextractor/man/figures/photoextractor_v3.png")
sticker(img.n, package="photoextractor",
        h_fill="#71c990",
        h_color="darkgreen",
        p_size=15,
        #p_color =
        p_y=1.55, # y position for package name
        s_x=1, s_y=.83, s_width=1.5, s_height=1.4,#,
        #dpi=150,
        filename="C:/CodigoR/photoextractor/man/figures/photoextractor_logo.png")



