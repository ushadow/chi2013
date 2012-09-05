# Copyright 2012 Google Inc. All Rights Reserved.
# Author: yingyin@google.com (Ying Yin)

source('key_detection_lib.R')
source('analysis_lib.R')

CrossValidationPosture <- function(df, keyboard, plot.name) {
  res.posture <- CrossValidation(df, keyboard, EvalKeyDetectionByPosture)
  res.base <- CrossValidation(df, keyboard, EvalKeyDetection)

  png(plot.name)
  merge.columns <- c('inputing_finger', 'user_id')
  res <- merge(res.base, res.posture, by = merge.columns, all.x = T)
  names <- res$user_id
  height <- t(subset(res, select = -c(user_id, inputing_finger)))
  barplot(height, names.arg = names, ylim = c(0, 1), beside = T)
  dev.off()
}

CrossValidation <- function(df, keyboard, fun, num.folds = 10, verbose = F) {
  # Args:
  #   df: Data frame.
  #
  # Returns:
  #   A data frame of user_id and accuracy.
  result <- NULL
  for (i in 1 : num.folds) {
    split.data <- SplitTrainTestCV(df, num.folds, i)
    fun <- match.fun(fun)
    res <- fun(split.data$train, split.data$test, keyboard, verbose)
    if (is.null(result)) {
      result <- res
    } else {
      result <- rbind(result, res)
    }
  }
  if (verbose) {
    print(result[result$key != result$detected.key, c('line_num',
                 'inputing_finger', 'user_id', 'key', 'xkeyboard',
                 'ykeyboard', 'xoffset', 'yoffset', 'detected.key')])
  }
  return(result)
}

CrossValidationWithinUser <- function(df, keyboard, num.folds = 10, verbose = F) {
  # Args:
  #   df: Data frame.
  #
  # Returns:
  #   A data frame of user_id and accuracy.
  result <- NULL
  for (i in 1 : num.folds) {
    split.data <- SplitTrainTestCV(df, num.folds, i)
    res <- EvalKeyDetectionByUserAndCombinedGaussians(split.data$train,
        split.data$test, keyboard, 0.5)
    if (is.null(result)) {
      result <- res
    } else {
      result <- rbind(result, res)
    }
  }
  return(result)
}

SplitTrainTestCV <- function(df, nfolds, fold.index) {
  # Splits the data into training and testing data.
  #
  # Args:
  #   df: Data frame of all data.
  #   train.test.split: The percentage of data used for training.
  res <- dlply(df, c('inputing_finger'), SplitUserCV,
               nfolds = nfolds, fold.index = fold.index)
  train.data <- do.call(rbind, lapply(res, function(x) x$train))
  test.data <- do.call(rbind, lapply(res, function(x) x$test))
  list(train = train.data, test = test.data)
}

SplitUserCV <- function(data, nfolds, fold.index) {
  # Splits the data for one posture into training and testing sets. The users in
  # in the training and testing data sets are different.
  #
  # Args:
  #   data: Data frame with data for one inputing finger.
  #   train.test.split: A float indicating the fraction of data to be used as
  #     training data.
  unique.ids <- unique(data$user_id)
  nids <- length(unique.ids)
  ntests <- floor(nids / nfolds)
  test.ids <- NULL
  if (ntests > 0) {
    test.ids <- unique.ids[((fold.index - 1) * ntests  + 1) :
                           (fold.index * ntests)]
  }
  train.data <- data[!(data$user_id %in% test.ids), ]
  test.data <- data[(data$user_id %in% test.ids), ]
  list(train = train.data, test = test.data)
}
