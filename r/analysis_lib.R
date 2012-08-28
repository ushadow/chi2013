# Copyright 2012 Google Inc. All Rights Reserved.
# Author: yingyin@google.com (Ying Yin)
library('plyr')
library('zoo')

kTimeOutlier <- 5000
kOutDir <- 'out/analysis/'
kLogDistance2Thresh <- 5 * 2
kTimeWindow <- 10

SplitTrainTest <- function(df, test.start.percent, test.end.percent = 1) {
  # Splits the data into training and testing data.
  #
  # Args:
  #   df: Data frame of all data.
  #   test.start.percent: The percentage point of the data where the test
  #       begins.
  #   test.end.percent: The percent point of the data where the test ends.
  res <- dlply(df, c('inputing_finger'), SplitUser,
               test.start.percent = test.start.percent,
               test.end.percent = test.end.percent)
  train.data <- do.call(rbind, lapply(res, function(x) x$train))
  test.data <- do.call(rbind, lapply(res, function(x) x$test))
  list(train = train.data, test = test.data)
}

SplitUser <- function(data, test.start.percent, test.end.percent = 1) {
  # Splits the data training and testing sets. The users in
  # in the training and testing data sets are different.
  #
  # Args:
  #   data: Data frame to split.
  #   train.test.split: A float indicating the fraction of data to be used as
  #     training data.
  unique.ids <- unique(data$user_id)
  # There is at least one user data in the training set.
  no.ids <- length(unique.ids)
  test.start.index <- floor(no.ids * test.start.percent) + 1
  test.end.index <- round(no.ids * test.end.percent)
  if (test.start.index >= 1 && test.end.index <= no.ids &&
      test.end.index >= test.start.index) {
    test.ids <- unique.ids[test.start.index : test.end.index]
    train.data <- data[!(data$user_id %in% test.ids), ]
    test.data <- data[data$user_id %in% test.ids, ]
    return(list(train = train.data, test = test.data))
  } else {
    stop('Wrong start and end percentages.')
  }
}

SplitByUser <- function(df, train.test.split) {
  # Splits the data set into training and test data sets for each users.
  #
  # Args:
  #   df: Data frame with all the data.
  res <- dlply(df, c('user_id'), SplitByPercentage,
               train.test.split = train.test.split)
  train.data <- do.call(rbind, lapply(res, function(x) x$train))
  test.data <- do.call(rbind, lapply(res, function(x) x$test))
  list(train = train.data, test = test.data)
}

SplitByPercentage <- function(data, train.test.split) {
  # Splits the data into training and test sets accordong to percentage.
  #
  # Args:
  #   data: Data frame.
  #   train.test.split: The percentage (0 - 1) to split the data.
  #
  # Returns:
  #   A list of training and test data frames.
  nrow <- nrow(data)
  no.train = max(1, round(nrow * train.test.split))
  train.data <- data[1 : no.train, ]
  if (no.train + 1 > nrow) {
    test.data <- NULL
  } else {
    test.data <- data[(no.train + 1) : nrow, ]
  }
  list(train = train.data, test = test.data)
}

Summary <- function(df) {
  ag <- aggregate(list(count = df$inputing_finger),
                  list(class = df$inputing_finger, user = df$user_id),
                  length)
  print(ag)
  print(summary(ag$class))
}

RemoveLeftHand <- function(df, user.df) {
  # Removes the data from left-handed users.
  #
  # Args:
  #   df: Data frame of all data.
  #   user.df: Data frame of user data with 'handedness' column.
  #
  # Returns:
  #   A data frame with left-handed users removed.
  right <- user.df$user_id[user.df$handedness == 'r']
  df[df$user_id %in% right, ]
}

OutputLibsvmFile <- function(data, filename) {
  # Output the data to a file in libsvm data format.
  #
  # The libsvm data format is as following:
  # <label> <index1>:<value1> <index2>:<value2> ...
  # .
  # .
  # .
  # <label> is the target value of the training data. For classification it
  # should be an integer which identifices a class. <index> is an integer
  # starting from 1, <value> is a real number. The indices must be in an
  # ascending order.
  #
  # Args:
  #   data: Data frame to be output.
  #   filename: String for the name of the output file.
  output <- as.numeric(data$inputing_finger) - 1
  restCols <- as.matrix(data[, c(which(names(data) != 'inputing_finger'))])
  for (i in 1 : ncol(restCols)) {
    c <- lapply(restCols[, i], function(x) paste(i, ':', x, sep = ''))
    output <- cbind(output, c)
  }
  sink(filename)
  write.table(output, row.names = F, col.names = F)
  sink()
}

FileBaseName <- function(path) {
  # Returns the base name (file name) from the path excluding the extension."
  #
  # Args:
  #   path: string of the path.
  #
  # Returns:
  #   A string of the base name of the file.
  sub('^([^.]*).*', '\\1', basename(path))
}

OutputArffFile <- function(data, path) {
  # Output the data to a file in arff data format.
  #
  # Args:
  #   data: Data frame to be output. The first column should be class.
  #   path: Path of the file to save the output. The name of file should not
  #         contain '.' except for the extension.
  fileBaseName <- FileBaseName(path)
  header <- paste('@relation', fileBaseName)
  classes <- paste(levels(data$inputing_finger), collapse = ', ')
  attribute.class <- paste('@attribute class {', classes, '}')
  header <- c(header, attribute.class)
  for (attribute in names(data)) {
    if (attribute != 'inputing_finger') {
      header <- c(header, paste('@attribute', attribute, 'numeric'))
    }
  }
  sink(path)
  writeLines(header)
  writeLines("@data")
  write.table(data, row.names = F, quote = F, col.names = F, sep = ",")
  sink()
}

CombineIAndT <- function(data) {
  # Combines the index finger and one thumb input postures into one class.
  #
  # Args:
  #   data: Data frame for 3 classes.
  #
  # Returns:
  #   A new data frame with I and T classes combined as T.
  newData <- data
  newData$inputing_finger[newData$inputing_finger == 'I'] <- 'T'
  newData$inputing_finger <- factor(newData$inputing_finger)
  return(newData)
}

ReadData <- function(filename) {
  # Reads data in a table format from a file. The table should have a header and
  # and comma delimited.
  #
  # Args:
  #   filename: String of the relative path of the input file.
  #
  # Returns:
  #   A data frame read from the file. The key column is changed to character.
  data <- read.table(filename, header = T, fill = T, sep = ',')
  return(data)
}

WriteTable <- function(df) {
  write.table(df, row.names = F, col.names = T, sep = ',', quote = F)
}

ComputeSingleTapFeatures <- function(df, timewindow = kTimeWindow) {
  # Computes features for each key tap. Rows with NA values are omnitted.
  # Time outliers are filtered (points with elapsed time greater than the
  # threshold value is filtered.)
  #
  # Args:
  #   df: data frame.
  #
  # Returns:
  #   A data frame with additional columns for single tap features, and
  #   the 'inputing_finger' column name is changed to 'class'.
  df <- na.omit(df)
  # Filters out time outliers.
  df <- subset(df, down_time_elapse < kTimeOutlier)
  df <- df[!(df$xtravel %in% c(0, 1)) | !(df$ytravel %in% c(0, 1)), ]
  distance2 <- df$xtravel * df$xtravel + df$ytravel * df$ytravel
  # Natural logarithm
  df$logdistance2 <- log(distance2)

  df <- NormalizeTime(df, timewindow)

  return(df)
}

ChangeColName <- function(df, old, new) {
  # Changes the column name of a data frame from old to new.
  class_index <- which(colnames(df) == old)
  colnames(df)[class_index] <- new
  return(df)
}

NormalizeTime <- function(df, timewindow) {
  ddply(df, c('user_id'), NormalizeTimeOne, timewindow = timewindow)
}

NormalizeTimeOne <- function(df, timewindow) {
  nrow = nrow(df)
  if (nrow < timewindow) {
    return(NULL)
  } else {
    roll.average <- rollapply(df$down_time_elapse, timewindow, mean)
    df <- df[timewindow : nrow, ]
    df$norm.time <- df$down_time_elapse / roll.average
    return(df)
  }
}

ProcessData <- function(filename, rangeSaveFile, rangeRestoreFile) {
  # Processes data and computes the features for single key tap.
  #
  # Args:
  #   filename: Path to the input data file.
  #   rangeSaveFile: String of the file name to save range data based on
  #     training data.
  #   rangeRestoreFile: String of the file name to restore the range for scaling
  #     test data.
  data <- ReadData(filename)
  data <- ComputeSingleTapFeatures(data)

  prefix <- FileBaseName(filename)

  res <- data[data$lr == 1 & data$logdistance2 > kLogDistance2Thresh,
              c('inputing_finger', 'line_num', 'down_time_elapse',
                'logdistance2', 'norm.time')]

  res <- Scale(res, -1, 1, rangeSaveFile, rangeRestoreFile)
  Output(res, paste(kOutDir, prefix, sep = ''))
  res.2c <- CombineIAndT(res)
  Output(res.2c, paste(kOutDir, prefix, '-2c', sep = ''))

  print(paste('Number of filtered instances = ', nrow(data)))
  print(paste('Number of output instances =', nrow(res)))
  unique.ids <- unique(data[c('user_id', 'inputing_finger')])
  print('User ids:')
  print(unique.ids)
  print(sprintf('Number of users = %d', nrow(unique.ids)))
}

Output <- function(df, prefix) {
  OutputArffFile(df, paste(prefix, '.arff', sep = ''))
}

Scale <- function(df, l, u, saveFile, restoreFile) {
  # Linear scaling of data.
  #
  # Args:
  #   df: Dada frame to be scales.
  #   l: Lower bound of the scaled data.
  #   u: Upper bound of the scaled data.
  #   saveFile: If it is not 'NA', save the range to the file, otherwise
  #     restoreFile should be provided, and the range is restored from the
  #     restoreFile.
  #   restoreFile: If saveFile is 'NA', restore the range from restoreFile.
  non.scale.columns <- c('inputing_finger', 'line_num')
  scale.data <- df[, !(names(df) %in% non.scale.columns)]
  range <- Range(scale.data, saveFile, restoreFile, l, u)
  res <- as.data.frame(lapply(colnames(scale.data), ScaleOne, df = df, l = l,
    u = u, range = range))
  colnames(res) <- colnames(scale.data)
  res <- cbind(df[non.scale.columns], res)
  return (res)
}

Range <- function(df, saveFile, restoreFile, l, u) {
  # Returns the min and max for each column of the data frame.
  #
  # Args:
  #   df (optional): data frame for which the range of each column needs to be
  #     determined. Not used if saveFile is not given and the range data is
  #     reloaded from restoreFile.
  #   saveFile (optional): string of the path of the file to save the range
  #     data.
  #   restoreFile (optional): string of the path of the file to reload the
  #     range data. It is only used if saveFile is not given or is 'NA'.
  if (!missing(saveFile) && saveFile != 'NA') {
    range <- as.data.frame(lapply(df, RangeOne))
    bounds <- c(max = u, min = l)
    range <- cbind(bounds, range)
    sink(saveFile)
    write.table(range, quote = F)
    sink()
  } else {
    # The fisrt column of the table is row names.
    range <- read.table(restoreFile, header = T, row.names = 1)
  }
  return (range)
}

RangeOne <- function(column) {
  # Calculates the max and min of each column if the column is numeric.
  if (is.numeric(column))
    c(max = max(column), min = min(column))
  else
    c(NA, NA)
}

ScaleOne <- function(cname, df, l, u, range) {
  # Linearly scales the data in one column with a given range and lower and
  # upper bound.
  # Args:
  #   l: lower bound of the scaled data.
  #   u: upper bound of the scaled data.
  column <- df[, cname]
  if (!is.numeric(column))
    return (column)

  max <- range['max', cname]
  min <- range['min', cname]
  if (max == min) {
    column <- 0
  } else {
    column <- l + (column - min) * (u - l) / (max - min)
  }
  return (column)
}
