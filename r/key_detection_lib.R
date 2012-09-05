# Copyright 2012 Google Inc. All Rights Reserved.
# Author: yingyin@google.com (Ying Yin)
library('mvtnorm')
library('plyr')

kMinGaussianDataPoints <- 50
kCovScale <- 1000

KeyGaussiansByPostureAndDirection <- function(df, keyboard, posture.keys,
    use.scale = F) {
  # Computes Gaussians for each key and posture, and different directions.
  #
  # Args:
  #   df: Data frame with inputing_finger and key columns. Y axis is upwards.
  #   keyboard: Data frame with xcenter and ycenter for each key. Y axis is
  #       upwards.
  #   posture.keys: Vector of keys for posture adaptation.
  #   use.scale: If true, the covariance is scaled to the same magnitude.
  #
  # Returns:
  #   Outputs the Gaussians for each posture, key and direction combination.
  df <- ComputeOffset(df, keyboard)
  print('base model')
  base.model <- ComputeBaseModel(df)
  print(base.model)
  cat("\n")
  df <- na.omit(df)
  df <- ComputeAngle(df, 8)
  dirs <- Directions(8)

  scale = 0
  if (use.scale)
    scale = kCovScale

  # Computes Gaussian model for each posture and key.
  df.posture <- df[df$key %in% posture.keys, ]
  res <- dlply(df.posture, c('inputing_finger', 'key'), KeyGaussiansByDirection,
               dirs = dirs, scale = scale)
  print(res[1 : length(res)])

  # Computes Gaussian model for each key.
  res <- dlply(df, c('key'), KeyGaussiansByDirection, dir = dirs, scale = scale)
  print(res[1 : length(res)])
}

KeyGaussiansByDirection <- function(df, dirs, scale) {
  res <- by(dirs, 1 : 8, KeyGaussianOneDirection, df = df,
            min.nrow = kMinGaussianDataPoints, scale = scale)
  all <- Gaussian(df, kMinGaussianDataPoints, scale)
  list(by.dirs = res, all = all)
}

KeyGaussianOneDirection <- function(dir, df, min.nrow, scale) {
  subset <- df[df$travel_angle < dir$ub & df$travel_angle >= dir$lb, ]
  g <- Gaussian(subset, min.nrow, scale)
}

Gaussian <- function(df, min.nrow = 1, scale = 0) {
  # Calculates a bivariate Gaussian model if there is enough data.
  #
  # Args:
  #   df: Data frame with xoffset and yoffset columns.
  #   min.nrow: If the data has fewer number of rows than min.row, returns
  #       NULL.
  #   scale: Value for scaling the covairance if it is greater than 0.
  #
  # Returns:
  #   A list containing the xoffset mean, yoffset mean and covariance matrix of
  #   x and y.
  if (nrow(df) < min.nrow)
    return(NULL)
  cov <- cov(df[c('xoffset', 'yoffset')])
  if (scale > 0) {
    scale <- scale / cov[1, 1]
    cov <- cov * scale
  }
  list(xmean = mean(df$xoffset), ymean = mean(df$yoffset), cov = cov)
}

KeyGaussiansByPosture <- function(df) {
  # Computes Gaussians for each key and inputing finger posture.
  #
  # Args:
  #   df: data frame containing the data.
  #
  # Returns:
  #   A list of gaussians with mean and sigma for each inputing finger and key
  #   combination.
  res <- dlply(df, c('inputing_finger', 'key'), Gaussian)
}

ComputeBaseModel <- function(df) {
  # Args:
  #   df: Data frame with 'xoffset' and 'yoffset' columns.
  return(list(xmean = 0, ymean = 0, cov = cov(df[c('xoffset', 'yoffset')])))
}

ComputeOffsetOne <- function(df, keyboard) {
  # Computes the offset of each x, y ccoordinates from the center of the target
  # key.
  key <- df[1, 'key']
  df$xoffset <- df$xkeyboard - keyboard$xcenter[keyboard$key == key]
  df$yoffset <- df$ykeyboard - keyboard$ycenter[keyboard$key == key]
  return(df)
}

ComputeOffset <- function(df, keyboard) {
  # Computes the x and y offsets.
  #
  # Returns:
  #   A data frame with xoffset and yoffset columns. The rows will be grouped
  #   according to keys.
  df$key <- as.character(df$key)
  keyboard$key <- as.character(keyboard$key)
  df <- ddply(df, .(key), ComputeOffsetOne, keyboard = keyboard)
}

ComputeAngle <- function(df, ndirs) {
  # Computes the angle of movement from the previous key. Y axis is upwards.
  #
  # Args:
  #   df: Data frame with NA values removed.
  #   ndirs: The number of directions.
  df <- df[!(df$xtravel %in% c(0, 1)) | !(df$ytravel %in% c(0, 1)), ]
  df$travel_angle <- atan2(-df$ytravel, df$xtravel)
  indices <- df$travel_angle >= 2 * pi * (ndirs - 1) / (ndirs * 2)
  df$travel_angle[indices] <- df$travel_angle[indices] - 2 * pi
  return(df)
}

KeyGaussians <- function(df, min.nrow = kMinGaussianDataPoints, scale = 0) {
  # Computes a Gaussian model for each key.
  #
  # Args:
  #   df: Data frame of the data points. Should have columns: 'key',
  #       'xoffset', 'yoffset'.
  #   min.nrow: Minimum number of rows in the data frame.
  #   scale: The scale for scaling the covariance of the Gaussian. If 0, no
  #       scaling is used.
  #
  # Returns:
  #   A list of Gaussian models for each key.
  if (is.null(df))
    return(NULL)
  res <- dlply(df, c('key'), Gaussian, min.nrow = min.nrow, scale = scale)
}

Directions <- function(ndirs) {
  # Args:
  #   ndirs: An integer specifying the number of directions to break down.
  # : has the highest precedence
  dirs <- c((-ndirs / 2) : (ndirs / 2 - 1))
  ub <- (dirs / ndirs + 1 / ndirs / 2) * 2 * pi
  lb <- (dirs / ndirs - 1 / ndirs / 2) * 2 * pi
  center.deg <- dirs * 360 / ndirs
  return(data.frame(ub, lb, center.deg))
}

EvalPostureModelWithDistance <- function(train.df, test.df, keyboard,
    verbose) {
  EvalKeyDetectionByPosture(train.df, test.df, keyboard, verbose,
                            'NegDistance2')
}

EvalKeyDetectionByPostureByKey <- function(train.df, test.df, keyboard,
                                           verbose) {
  # Evaluates key detection accuracy by using one Gaussian model for each key
  # for each posture.
  #
  # Args:
  #   train.df: Data frame of training data. Must have 'inputing_finger' column.
  #   test.df: Data frame of test data. Must have 'inputing_finger' column.
  summary <- NULL
  all.letters <- c(letters, ' ')
  combined.gaussians <- KeyGaussians(train.df, kMinGaussianDataPoints)
  for (l in levels(train.df$inputing_finger)) {
    train1 <- train.df[train.df$inputing_finger == l, ]
    test1 <- test.df[test.df$inputing_finger == l, ]
    res <- lapply(all.letters, EvalKeyDetectionByKey,
        train.df = train1, test.df = test1, keyboard = keyboard,
        combined.gaussians = combined.gaussians, verbose = verbose)
  }
  do.call(rbind, res)
}

EvalKeyModel <- function(train.df, test.df, keyboard, verbose = F) {
  # Evaluates key adaptive model.
  #
  # Args:
  #   train.df: Training data.
  #i  test.df: Test data with xkeyboard and ykeyboard columns.
  base.model <- ComputeBaseModel(train.df)
  res <- EvalKeyDetection(train.df = train.df,
         test.df = test.df, keyboard = keyboard, base.model = base.model,
         verbose = verbose)
}

EvalKeyDetectionByKey <- function(key, train.df, test.df, keyboard,
    combined.gaussians = NULL, base.model = NULL, verbose = F)
{
  # Evaluates key detection accuracy by using one Gaussian model for each key
  # for each posture.
  #
  # Args:
  #   train.df: Data frame of training data. Must have 'inputing_finger' column.
  #   test.df: Data frame of test data. Must have 'inputing_finger' column.
  #   combined.gaussians: Backoff gaussians when no guassians are available from the ones
  #       trained from training data.
  summary <- NULL
  train1 <- train.df[train.df$key == key, ]
  res <- EvalKeyDetection(train1, test.df, keyboard, kMinGaussianDataPoints,
      combined.gaussians = combined.gaussians, base.model = base.model, verbose = verbose)
  if (is.null(summary)) {
    summary <- res
  } else {
    summary <- rbind(summary, res)
  }
  return(summary)
}

EvalKeyDetection <- function(train.df, test.df, keyboard,
    min.key.data.points = kMinGaussianDataPoints,
    combined.gaussians = NULL, use.biletter = F, biletters = NULL, verbose = F,
    base.model = NULL, fun = 'dmvnorm') {
  # Evaluates the key detection accuracy based on Gaussian models built with the
  # training data and tested on test data.
  #
  # Args:
  #   train.df: Data frame of training data. Should have 'inputing_finger',
  #       'user_id', 'xoffset', 'yoffset' columns.
  #   test.df: Data frame of test data. Should have 'inputing_finger',
  #       'user_id', 'xkeyboard', 'ykeyboard' colunms.
  #   min.key.data.points: The minimum number of points needed to train the
  #       Gaussian model for each key.
  #   combined.gaussians: A list of Gaussians for each key.
  #   base.model: One Gaussian.
  #
  # Returns:
  #   A data frame with detected.key column.
  if (nrow(test.df) == 0)
    return(NULL)

  gaussians <- KeyGaussians(train.df, min.key.data.points)

  biletter.gaussians <- NULL
  if (use.biletter) {
    biletter.gaussians <- BiletterGaussians(train.df, 5)
    print(biletter.gaussians[1 : length(biletter.gaussians)])
  }
  all.letters <- c(letters, ' ')
  # sapply returns a matrix.
  res <- sapply(all.letters, ComputeMetric, x = test.df$xkeyboard,
                y = test.df$ykeyboard, keyboard = keyboard,
                gaussians = gaussians, combined.gaussians = combined.gaussians,
                base.model = base.model, fun = fun)
  if (use.biletter) {
    for (biletter in biletters) {
      first.letter <- substr(biletter, 1, 1)
      second.letter <- substr(biletter, 2, 2)
      indices <- which(test.df$detected.key == first.letter)
      next.indices <- indices + 1
      prob <- rep.int(0, nrow(test.df))
      prob[next.indices] <- ComputeMetric(biletter,
          test.df$xoffset[next.indices], test.df$yoffset[next.indices],
          biletter.gaussians)
      res <- cbind(res, prob)
      all.letters <- c(all.letters, second.letter)
    }
  }
  test.df$detected.key <- all.letters[max.col(res)]
  if (verbose) {
    print("Training users:")
    print(unique(train.df$user_id))
    print("Test users:")
    print(unique(test.df$user_id))
    print(gaussians[1 : length(gaussians)])
  }
  return(test.df)
}

EvalBaseModelWithCov <- function(train.df, test.df, keyboard, verbose) {
  # Evaluates key detection using base model.
  # Args:
  #   train.df: Data frame of training data set with 'xoffset' and yoffset
  #   columns.
  base.model <- ComputeBaseModel(train.df)
  if (verbose)
    print(base.model)
  DetectKey(test.df, keyboard, base.model)
}

EvalBaseModel <- function(train.df, test.df, keyboard, verbose) {
  base.model <- list(xmean = 0, ymean = 0, cov = matrix(c(400, 0, 0, 400), ncol = 2))
  if (verbose)
    print(base.model)
  DetectKey(test.df, keyboard, base.model)
}

DetectKey <- function(test.df, keyboard, key.model = NULL,
    combined.model = NULL, base.model, fun = dvmnorm) {
  # Computes the detected key.
  all.letters <- c(letters, ' ')
  res <- sapply(all.letters, ComputeMetric, x = test.df$xkeyboard,
                y = test.df$ykeyboard, keyboard = keyboard,
                base.model = base.model, gaussians = key.model,
                combined.gaussians = combined.model, fun = fun)
  test.df$detected.key <- all.letters[max.col(res)]
  return(test.df)
}

EvalUserResult <- function(df) {
  # Evaludates the key detection accuracy for a user.
  #
  # Args:
  #   df: Data frame should have 'inputing_finger' column.
  accuracy.table <- table(df$detected.key == df$key)
  no.true <- 0
  if ('TRUE' %in% names(accuracy.table)) {
    no.true <- accuracy.table['TRUE']
  }
  accuracy <- no.true / sum(accuracy.table)
  return(data.frame(user_id = df[1, 'user_id'],
                    inputing_finger = df[1, 'inputing_finger'],
                    accuracy = accuracy))
}

EvalKeyDetectionByUserAndCombinedGaussians <- function(train.df, test.df,
    keyboard, within.user.split, use.biletter = F, biletters = NULL) {
  # Evaluates key detection accuracy with user adaptation.
  combined.gaussians <- KeyGaussians(train.df)
  print(combined.gaussians)
  EvalKeyDetectionByUser(test.df, keyboard, within.user.split,
                         combined.gaussians, use.biletter, biletters)
}

EvalKeyDetectionByUser <- function(df, keyboard, split,
    combined.gaussians = NULL, use.biletter = F, biletters = NULL) {
  users <- unique(df$user_id)
  summary <- NULL
  for (user in users) {
    user.data <- df[df$user_id == user, ]
    split.data <- dlply(user.data, .(key), SplitKey, split = split)
    train1 <- do.call(rbind, lapply(split.data, function(x) x$train))
    test1 <- do.call(rbind, lapply(split.data, function(x) x$test))
    res <- EvalOneUser(train1, test1, keyboard, combined.gaussians,
                       use.biletter, biletters)
    if (is.null(summary)) {
      summary <- res
    } else {
      summary <- rbind(summary, res)
    }
  }
  return(summary)
}

SplitKey <- function(df, split) {
  nrow <- nrow(df)
  last.train.index <- round(nrow * split)
  train <- df[1 : last.train.index, ]
  if (last.train.index >= nrow) {
    test <- NULL
  } else {
    test <- df[(last.train.index + 1) : nrow, ]
  }
  list(train = train, test = test)
}

EvalOneUser <- function(train, test, keyboard, combined.gaussians = NULL,
    use.biletter = F, biletters = NULL, verbose = F) {
  if (verbose) {
    print("Personalized training set:")
    ag <- aggregate(list(count = train$user_id), list(key = train$key),
                    length)
    print(ag)
  }

  test.res <- EvalKeyDetection(train, test, keyboard, 10,
      combined.gaussians, use.biletter, biletters, verbose = F)
  return(EvalUserResult(test.res))
}

ComputeMetric <- function(key, x, y, keyboard, gaussians = NULL,
    combined.gaussians = NULL, base.model = NULL, fun = 'dmvnorm') {
  # Computes probability density of (x, y) from a given key's Gaussian.
  # Args:
  #   key: The key whose Gaussian distribution is used to compute the
  #       probability.
  #   x: A vector of x coordinates.
  #   y: A vector of y coordinates.
  #   gaussians: A list of Gaussians for each key.
  #   combined.gaussian (optional): A list of Gaussians that is used when there
  #       there is no Gaussian for the key in gaussians. These serve as a
  #       backup.
  #
  # Returns:
  #   A vector of densities. If there is no Gaussian model for the key, the
  #   density is 0.

  if (missing(keyboard)) {
    stop('Argument keyboard is missing')
  }

  if (is.null(gaussians)) {
    g <- NULL
  } else {
    g <- gaussians[key][[1]]
  }
  if (is.null(g) && !is.null(combined.gaussians))
    g <- combined.gaussians[key][[1]]
  if (is.null(g)) {
    if (!is.null(base.model)) {
      g <- base.model
    } else {
      return(rep.int(0, length(x)))
    }
  }
  xoffset <- x - keyboard$xcenter[keyboard$key == key]
  yoffset <- y - keyboard$ycenter[keyboard$key == key]
  fun <- match.fun(fun)
  fun(cbind(xoffset, yoffset), mean = c(g[[1]], g[[2]]), sigma = g[[3]])
}

NegDistance2 <- function(offsets, mean, ...) {
  # Computes the negative square distance from the point to the center.
  diff <- offsets - mean
  sqr <- diff * diff
  return (- sqr[, 1] - sqr[, 2])
}

BiletterGaussians <- function(df, biletters) {
  # Returns:
  #   A list of Gaussians for each biletters.
  df <- na.omit(df)
  lapply(biletters, OneBiletterGaussian, df = df)
}

OneBiletterGaussian <- function(biletter, df) {
  subset <- df[df[biletter] == 1, ]
  Gaussian(subset)
}



