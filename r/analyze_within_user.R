source('cross_validation_lib.R')

AnalyzeWithinUser <- function(df, keyboard, key, plot.file) {
  # Args:
  #   df: Data frame of the whole data set.
  df <- CombineIAndT(df)
  df$ykeyboard <- -df$ykeyboard
  keyboard$ycenter <- -keyboard$ycenter
  df <- ComputeOffset(df, keyboard)
  splits <- c(0, 10, 20, 30, 40, 50, 60, 70)
  num.folds <- 10

  result <- NULL
  for (i in 1 : num.folds) {
    split.data <- SplitTrainTestCV(df, num.folds, i)
    train <- split.data$train
    test <- split.data$test
    print('training users:')
    print(unique(train$user_id))
    print('testing users:')
    print(unique(test$user_id))
    users <- unique(test$user_id)
    combined.gaussian <- KeyGaussians(train)
    for (user in users) {
      user1 <- df[df$user_id == user & df$key == key, ]
      test1 <- user1[(max(splits) + 1) : nrow(user1), ]
      for (split in splits) {
        train1 <- user1[1 : split, ]
        res <- EvalOneUser(train1, test1, keyboard, combined.gaussian)
        if (is.null(result)) {
          result <- cbind(split = split, res)
        } else {
          result <- rbind(result, cbind(split = split, res))
        }
      }
    }
  }
  print(unique(result$user_id))
  result.0 <- result[result$split == 0, ]
  baseline <- (1 - mean(result.0$accuracy)) * 100
  result <- result[result$split != 0, ]
  ag <- aggregate(list(accuracy = result$accuracy),
                  list(split = result$split), mean)
  pdf(plot.file)
  xlab = sprintf('Number of points for individual adaptation for key %s', key)
  x <- ag$split
  colors <- c('black', 'green')
  plot(x, (1 - ag$accuracy) * 100, type = 'b', xlab = xlab,
       ylab = 'key detection error rate in %', col = colors[1])
  lines(x, rep(baseline, length(x)), col = colors[2])
  legend('topright', c('error rate of individual adaptive model for key e',
          'error rate of key adaptive model'), col = colors, lwd = 1, cex = 0.8)
  dev.off()
}
