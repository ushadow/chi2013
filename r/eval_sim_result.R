source('plot_lib.R')

PlotPairedEllipses <- function(r1, r2, keyboard, key, predicted.key) {
  keyboard$bottom <- -keyboard$bottom
  keyboard$top <- -keyboard$top
  keyboard$ycenter <- -keyboard$ycenter
  r1$ykeyboard <- -r1$ykeyboard

  keybounds <- keyboard[keyboard$key %in% c(key, predicted.key), ]

  xrange <- c(min(keybounds$left), max(keybounds$right))
  yrange <- c(min(keybounds$bottom), max(keybounds$top))

  print(table(diff$inputing_finger))
  plot(xrange, yrange, type = 'n')
  DrawKeyWithText(keybounds)
  points(diff$xkeyboard, diff$ykeyboard)
}

WrongDetection <- function(df, key, predicted.key) {
  print(key)
  df[df$key != df$predicted_key & df$key == key &
     df$predicted_key == predicted.key, ]
}

ErrorDiff <- function(r1, r2) {
  e1 <- r1$line_num[r1$key != r1$predicted_key]
  e2 <- r2$line_num[r2$key != r2$predicted_key]
  e1.e2 <- setdiff(e1, e2)
  r1[r1$line_num %in% e1.e2, ]
}
