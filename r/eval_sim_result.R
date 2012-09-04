source('plot_lib.R')

PlotPairedEllipses <- function(r1, r2, df, keyboard, key, predicted.key,
    inputing_finger, file.name) {
  error.diff <- ErrorDiff(r1, r2)
  error.diff <- error.diff[error.diff$key == key &
                           error.diff$predicted_key == predicted.key, ]
  keybounds <- keyboard[keyboard$key %in% c(key, predicted.key), ]

  ellipses.data <- df[(df$key %in% c(key, predicted.key))
  & df$inputing_finger == inputing_finger, ]

  PlotPointsEllipses(error.diff, ellipses.data, keybounds, file.name)
}

WrongDetection <- function(df, key, predicted.key) {
  print(key)
  df[df$key != df$predicted_key & df$key == key &
     df$predicted_key == predicted.key, ]
}

ErrorDiff <- function(r1, r2) {
  # Errors in r1 but not in r2.
  e1 <- r1$line_num[r1$key != r1$predicted_key]
  e2 <- r2$line_num[r2$key != r2$predicted_key]
  e1.e2 <- setdiff(e1, e2)
  r1[r1$line_num %in% e1.e2, ]
}

PlotPointsEllipses <- function(points, ellipses.data, keybounds, file.name) {
  keybounds$bottom <- -keybounds$bottom
  keybounds$top <- -keybounds$top
  keybounds$ycenter <- -keybounds$ycenter
  points$ykeyboard <- -points$ykeyboard
  ellipses.data$ykeyboard <- -ellipses.data$ykeyboard

  xrange <- c(30, 160)
  yrange <- c(10, -90)

  pdf(file.name)
  SetPlotSize(xrange, yrange, 3)
  plot(xrange, yrange, type = 'n', xlab = '', ylab = '', ann = F)
  DrawKeyWithText(keybounds)
  points(points$xkeyboard, points$ykeyboard, pch = 19, col = 'red', cex = 0.4)

  color <- 'blue'
  keys <- unique(ellipses.data$key)
  for (i in 1 : length(keys)) {
    data <- ellipses.data[ellipses.data$key == keys[i], ]
    dataEllipse(data$xkeyboard, data$ykeyboard, levels = c(0.95), col = color, plot.points = F, add = T)
  }
  title(xlab = 'x coordinate relative to the top left of the keyboard',
        ylab = 'y coordinate relative to the top left of the keyboard')
  legend('bottomright', c('posture and key adaptive model for two-thumb'), col = color, lwd = 1, cex = 0.8)
  dev.off()
}

