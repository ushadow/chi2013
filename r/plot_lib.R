# Copyright 2012 Google Inc. All Rights Reserved.
# Author: yingyin@google.com (Ying Yin)
#
# Library that contains plot related functions.
library(car)
library(graphics)

source('analysis_lib.R')
source('key_detection_lib.R')

kInchPerPixel <- 1 / 72

PlotEllipsesOneLetterAndBiletter <- function(df, pattern, keyboard,
                                             output.prefix) {
  # Plots ellipses for one letter and the biletter pattern.
  #
  # Args:
  #   df: Data frame containing data for plotting.
  #   patter: The biletter pattern to plot.
  #   keyboard: Data frame with keyboard layout inforamtion.
  #   output.prefix: The string prefix for the output image file.
  df <- CombineIAndT(df)

  # Invert all y coordinates
  df$ykeyboard <- -df$ykeyboard
  keyboard$top <- -keyboard$top
  keyboard$bottom <- -keyboard$bottom
  keyboard$ycenter <- -keyboard$ycenter

  nchar <- nchar(pattern)
  key2 <- substr(pattern, nchar, nchar)
  key1 <- substr(pattern, 1, 1)
  subset1 <- df[df$key == key2, ]
  limits <- list(xlim = c(30, 160), ylim = c(10, -90))
  subset2 <- subset1[subset1$inputing_finger == 'T', ]

  df <- na.omit(df)
  subset3 <- df[df[pattern] == 1, ]
  if (length(unique(subset3$key)) > 1) {
    print(unique(subset3$key))
    stop('More than one keys selected.')
  }
  subset4 <- subset3[subset3$inputing_finger == 'T', ]
  df.list <- list(subset1, subset2, subset3, subset4)
  legends <- c(sprintf('all letter %s', key2),
               sprintf('letter %s with one finger', key2),
               sprintf('letter %s after %s', key2, key1),
               sprintf('letter %s after %s with one finger',
                       key2, key1))

  pdf(sprintf('%s-%s.pdf', output.prefix, pattern))
  PlotEllipses(df.list, limits, legends)
  bounds <- keyboard[keyboard$key == key2, ]
  DrawKeyWithText(bounds)
  dev.off()
}

RgbaColors <- function(colors, alpha) {
  # Creates rgba colors from color and alpha values
  #
  # Args:
  #   colors: A vector of color names.
  #   alpha: A vector of alpha values between 0 and 255.
  rgb.colors <- t(col2rgb(colors))
  rgb(rgb.colors[, 1], rgb.colors[, 2], rgb.colors[, 3], alpha = alpha,
      maxColorValue = 255)
}

PlotEllipses <- function(df.list, limits, legends) {
  SetPlotSize(limits$xlim, limits$ylim, 3)

  ncolors <- length(df.list)
  colors <- c('black', 'red', 'blue', 'cyan', 'orange', 'magenta')
  rgb.colors <- t(col2rgb(colors)) / 255

  plot(limits$xlim, limits$ylim, type = 'n', xlab = '', ylab = '', ann = F)

  for (i in 1 : length(df.list)) {
    dataEllipse(df.list[[i]]$xkeyboard, df.list[[i]]$ykeyboard,
                levels = c(0.95), col = rgb(rgb.colors[i, 1], rgb.colors[i, 2],
                rgb.colors[i, 3], alpha = 1), plot.points = F, add = T)
  }
  title(xlab = 'x coordinate relative to the top left of the keyboard',
        ylab = 'y coordinate relative to the top left of the keyboard')
  legend('bottomleft', legends, col = colors, lwd = 1, cex = 0.8)
}

Limits <- function(df) {
  xlim <- c(min(df$xkeyboard), max(df$xkeyboard))
  ylim <- c(min(df$ykeyboard), max(df$ykeyboard))
  list(xlim = xlim, ylim = ylim)
}

PlotEllipsesByPosture <- function(df, bounds, xlim, ylim) {
  # Args:
  #   df: data frame of processed data with 'class' column.
  classes <- c('TT', 'T', 'I')
  ncolors <- length(classes) + 1
  colors <- palette()[1 : ncolors]

  dataEllipse(df$xkeyboard, df$ykeyboard, levels = c(0.95),
              col = colors[1], plot.points = T, add = F, cex = 0.5,
              ylim = ylim,xlim = xlim, ann = F)

  title(xlab = 'x coordinate relative to the top left of the keyboard')
  title(ylab = 'y coordinate relative to the top left of the keyboard')

  for (i in 1 : length(classes)) {
    c <- classes[i]
    subset.class <- df[df$inputing_finger == c, ]
    points(subset.class$xkeyboard, subset.class$ykeyboard, cex = 0.5,
         col = colors[i + 1])
  }
  for (i in 1 : length(classes)) {
    c <- classes[i]
    subset.class <- df[df$class == c, ]
    dataEllipse(subset.class$xkeyboard, subset.class$ykeyboard,
                levels = c(0.95), plot.points = F, add = T,
                col = colors[i + 1])
  }
  rect(bounds$left, bounds$bottom, bounds$right, bounds$top)
  legend('topleft', c('all postures', 'two thumbs', 'one thumb',
                      'one finger'), col = colors, lwd = 1, bty = "n")
}

PlotEllipsesByDirection <- function(df, key, keyboard, output.prefix) {
  # Args:
  #   df: data frame with NA values filtered out and has travel_angle column.
  dirs <- Directions()
  df <- df[df$key == key, ]
  xlim <- c(min(df$xkeyboard), max(df$xkeyboard))
  ylim <- c(max(df$ykeyboard), 0)
  keybounds <- keyboard[keyboard$key == key, ]
  by(dirs, 1 : nrow(dirs), PlotEllipsesOneDirection, df = df, key = key,
     keybounds = keybounds, xlim = xlim, ylim = ylim,
     output.prefix = output.prefix)
}

PlotEllipsesOneDirection <- function(dir, df, key, keybounds, xlim, ylim,
    output.prefix) {
  output <- sprintf('%s-%s_%d.png', output.prefix, key, dir$center.deg)
  png(filename = output)
  SetPlotSize(xlim, ylim)
  subset <- df[df$travel_angle < dir$ub & df$travel_angle >= dir$lb, ]
  PlotEllipsesByPosture(subset, keybounds, xlim, ylim)
  title(main = sprintf('0.95 confidence ellipses for %s when the direction of
      movement from the previous tap is about %d degree', key, dir$center.deg))
  dev.off()
}

Directions <- function() {
  # Returns the lower and upper bounds and the center for four directions: -90,
  # -45, 0, 45.
  #
  # Returns:
  #   A data frame with ub, lb and center.deg columns.
  dirs <- c(-2 : 1)
  ub <- (dirs / 4 + 1 / 8) * pi
  lb <- (dirs / 4 - 1 / 8) * pi
  center.deg <- dirs * 45
  return(data.frame(ub, lb, center.deg))
}

PlotEllipsesMarginalAndByDirection <- function(df, key, class, keybounds,
    xlim, ylim, output.prefix) {
  # Plots ellipses for a key with one posture class with all direction combined
  # and with different directions.
  #
  # Args:
  #   df: Data frame of data for one key.
  #   key: Character of the key to plot.
  #   class: String of the posture class.
  #   keybounds: Vector of the top, right, bottom and left of the key on the
  #       keyboard.
  png(filename = sprintf('%s-%s-%s.png', output.prefix, key, class))
  SetPlotSize(xlim, ylim)
  dirs <- Directions()
  ndirs <- nrow(dirs)
  colors = palette()[1 : (ndirs + 1)]
  df <- df[df$class == class, ]
  dataEllipse(df$xkeyboard, df$ykeyboard, levels = c(0.95), col = colors[1],
              cex = 0.5, ylim = ylim, xlim = xlim, ann = F)
  PlotEllipsesAllDirections(df, dirs, colors, T)
  PlotEllipsesAllDirections(df, dirs, colors, F)
  rect(keybounds$left, keybounds$bottom, keybounds$right, keybounds$top)
  dir.names <- paste(dirs$center.deg, 'degree')
  legend('topleft', c('all angles', dir.names), col = colors, lwd = 1)
  class.names <- list(I = 'one finger', T = 'one thumb', TT = 'two thumbs')
  title(main = sprintf('0.95 confidence ellipses for %s with posture %s broken
      down to different movement directions', key, class.names[class]))
  dev.off()
}

PlotEllipsesAllDirections <- function(df, dirs, colors, plot.points) {
 for (i in 1 : nrow(dirs)) {
    subset <- df[df$travel_angle < dirs$ub[i] & df$travel_angle >= dirs$lb[i], ]
    dataEllipse(subset$xkeyboard, subset$ykeyboard, levels = c(0.95),
                col = colors[i + 1], add = T, cex = 0.5,
                plot.points = plot.points )
  }
}

SetPlotSize <- function(xlim, ylim, scale = 1) {
  xrange <- abs(xlim[2] - xlim[1] + 1)
  yrange <- abs(ylim[2] - ylim[1] + 1)
  par(pin = c(kInchPerPixel * xrange * scale, kInchPerPixel * yrange * scale))
  print(par()['pin'])
}

PlotEllipsesByPostureThenDir <- function(df, key, keyboard, output.prefix) {
  # Args:
  #   df: data frame with travel_angle column.
  classes <- c('TT', 'T', 'I')
  keybounds <- keyboard[keyboard$key == key, ]
  df <- df[df$key == key, ]
  xlim <- c(min(df$xkeyboard), max(df$xkeyboard))
  ylim <- c(max(df$ykeyboard), 0)
  for (c in classes) {
    PlotEllipsesMarginalAndByDirection(df, key, c, keybounds, xlim, ylim,
        output.prefix)
  }
}

Stats <- function(df, keyboard, output.prefix) {
  # Computes some statistics of the data.
  #
  # Args:
  #   data: Data frame with columns inputing_finger, down_time_elapse.
  #   output.prefix: String of the prefix of the output filename.
  Summary(df)
  filename <- paste(output.prefix, '-time-stats.png', sep = '')
  png(filename <- filename)
  time <- boxplot(down_time_elapse ~ inputing_finger, df, range = 3)
  dev.off()
  statTable <- time$stats
  colnames(statTable) <- time$names
  rownames(statTable) <- c('1st Qu. - 3 x IQR', '1st Qu.', 'median',
                           '3rd Qu.', '3rd Qu. + 3 x IQR')
  print(statTable)

  PlotEllipsesOneLetterAndBiletter(df, 'he', keyboard, output.prefix)
  #df <- ComputeSingleTapFeatures(df)
  #keys <- c('e', 'h')
  #for (key in keys) {
  #  PlotEllipsesByDirection(df, key, keyboard, output.prefix)
  #  PlotEllipsesByPostureThenDir(df, key, keyboard, output.prefix)
  #}
  Boxplots(df, output.prefix)
}

BoxplotCor <- function(df, out.file) {
  # Makes a boxplot of the correlation feature for each input classes.
  #
  # Args:
  #   df: Data frame with class and feature columns.
  #`  out.file: String of the output file name.
  df <- ComputeSingleTapFeatures(df)
  df <- CombineIAndT(df)
  res <- ComputeCorrelation(df, 10)
  pdf(out.file)
  boxplot(cor ~ inputing_finger, data = res)
  ylab <- 'correlation between time and log square disance'
  title(xlab = 'postures', ylab = ylab)
  dev.off()
}

ComputeCorrelation <- function(df, numKeys) {
  cor <- dlply(df, c('inputing_finger', 'user_id'), ComputeFeaturesOneUser,
               numKeys = numKeys)
  res <- do.call(rbind, cor)
  na.omit(res)
}

ComputeFeaturesOneUser <- function(df, numKeys) {
  classLabel <- df[1, 'inputing_finger']
  if (classLabel == 'TT') {
    classLabel <- 'two thumbs'
  } else {
    classLabel <- 'one finger'
  }
  user.data.nrow <- nrow(df)
  result.nrow <- floor(user.data.nrow / numKeys)
  inputing_finger <- as.factor(rep(classLabel, result.nrow))
  user.data <- df[1 : (result.nrow * numKeys), ]
  user.data$label <-rep(c(1 : result.nrow), each = numKeys)
  cor <- ddply(user.data, .(label), ComputeCorrelationOne)
  return(data.frame(inputing_finger, cor))
}

ComputeCorrelationOne <- function(df) {
  c(cor = cor(df$down_time_elapse, df$logdistance2))
}

PlotTimeDistance <- function(df, out.file, alpha = 255 * c(1, 0.66, 0.33)) {
  # Analyzes the time and distance relationship and plots a graph.
  #
  # Args:
  #   df: Data frame with logdistance column.
  tt <- df[df$inputing_finger == 'TT', ]
  t <- df[df$inputing_finger == 'T', ]
  i <- df[df$inputing_finger == 'I', ]
  # Analyze relationship between time and log distance.
  lm.r.tt <- lm(tt$down_time_elapse ~ tt$logdistance2)
  lm.r.t <- lm(t$down_time_elapse ~ t$logdistance2)
  lm.r.i <- lm(i$down_time_elapse ~ i$logdistance2)

  colors <- c('black', 'blue', 'red')
  rgba.colors <- RgbaColors(colors, alpha)
  point.size = 0.05
  png(out.file)
  plot(tt$logdistance2, tt$down_time_elapse, ylim = c(100, 1000), pch = 19,
      cex = point.size, ann = F, col = rgba.colors[1])
  abline(lm.r.tt, col = colors[1])
  points(t$logdistance2, t$down_time_elapse, col = rgba.colors[2], pch = 19,
      cex = point.size)
  abline(lm.r.t, col = colors[2])
  points(i$logdistance2, i$down_time_elapse, col = rgba.colors[3], pch = 19,
      cex = point.size)
  abline(lm.r.i, col = colors[3])

  legend(0, 1000, c("two thumbs", "one thumb", "one finger"), cex = .8,
         col = colors, pch = 19)

  title(xlab = "log sqaure distance (px) between consecutive key presses")
  title(ylab = "key down action elapse time (ms) between consecutive key presses")
  dev.off()
}

KeyBoundary <- function(train.df, keyboard, file.name, fun, posture = 'T') {
  xrange <- c(min(keyboard$left), max(keyboard$right))
  yrange <- c(min(keyboard$top), max(keyboard$bottom))
  width <- xrange[2] - xrange[1] + 1
  height <- yrange[2] - yrange[1] + 1
  x <- rep(xrange[1] : xrange[2], times = height)
  y <- rep(yrange[1] : yrange[2], each = width)

  train.df <- CombineIAndT(train.df)
  train.df$ykeyboard <- -train.df$ykeyboard
  keyboard$ycenter <- -keyboard$ycenter
  test.df <- data.frame(xkeyboard = x, ykeyboard = -y,
                        inputing_finger = rep(posture, length(x)))
  train.df <- ComputeOffset(train.df, keyboard)
  fun <- match.fun(fun)
  detected.key <- fun(train.df, test.df, keyboard)$detected.key
  detected.key <- match(detected.key, c(letters, ' ', '.'))
  image <- rainbow(27, s = 0.6)[detected.key]

  pdf(file.name, width = width * kInchPerPixel, height = height * kInchPerPixel)
  SetPlotSize(xrange, yrange)
  par(mar = rep(0, 4))
  plot(xrange, yrange, type = 'n', ann = F, xlab = '', ylab = '', xaxs = 'i',
       yaxs = 'i')
  rasterImage(matrix(image, ncol = width, byrow = T), xrange[1], yrange[1],
              xrange[2], yrange[2])
  by(keyboard, 1 : nrow(keyboard), DrawKey, height = yrange[2] + yrange[1])
  text(keyboard$xcenter, yrange[2] + yrange[1] + keyboard$ycenter,
       toupper(keyboard$key), col = 'black', cex = 1.5)
  dev.off()
}

DrawKey <- function(df, height) {
  rect(df$left, height - df$bottom, df$right, height - df$top)
}

DrawKeyWithText <- function(keybound) {
  rect(keybound$left, keybound$bottom, keybound$right, keybound$top)
  key <- toupper(keybound$key)
  text(keybound$xcenter, keybound$ycenter, key, col = 'black', cex = 1.5)
}

PlotThreshAccuracy <- function(df, baseline, out.file) {
  pdf(out.file)
  ylim <- c(min(baseline, df$key_accuracy), max(df$key_accuracy))
  colors <- c('black', 'green')
  plot(df$thresh, df$key_accuracy, xlab = 'confidence threshold',
       ylab = 'key detection accuracy', type = 'b', ylim = ylim,
       col = colors[1])
  lines(df$thresh, rep(baseline, nrow(df)), col = colors[2])
  legend('topleft', c('Posture & key adaptive model',
         'Key adaptive only model'), col = colors, lwd = 1)
  dev.off()
}
