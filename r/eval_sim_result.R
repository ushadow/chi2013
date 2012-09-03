source('plot_lib.R')

PlotPairedEllipses <- function(r1, r2, keyboard, key, predicted.key) {
  error.diff <- ErrorDiff(r1, r2)
  error.diff <- error.diff[error.diff$key == key &
                           error.diff$predicted_key == predicted.key, ]
  keybounds <- keyboard[keyboard$key %in% c(key, predicted.key), ]

  PlotPointsEllipses(error.diff, NULL, keybounds)
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

PlotPointsEllipses <- function(points, ellipses.data, keybounds) {
  keybounds$bottom <- -keybounds$bottom
  keybounds$top <- -keybounds$top
  keybounds$ycenter <- -keybounds$ycenter
  points$ykeyboard <- -points$ykeyboard

  xrange <- c(min(keybounds$left), max(keybounds$right))
  yrange <- c(min(keybounds$bottom), max(keybounds$top))

  plot(xrange, yrange, type = 'n')
  DrawKeyWithText(keybounds)
  points(points$xkeyboard, points$ykeyboard, pch = 19, col = 'red')
}
