# Copyright 2012 Google Inc. All Rights Reserved.
# Author: yingyin@google.com (Ying Yin)
source('key_detection_lib.R')
source('analysis_lib.R')
source('cross_validation_lib.R')

args <- commandArgs(trailingOnly = T)

file <- args[1]
keyboard.file <- args[2]
user.file <- args[3]
output.file <- args[4]

df <- ReadData(file)
user.data <- ReadData(user.file)
df <- CombineIAndT(df)
keyboard <- ReadData(keyboard.file)

df$ykeyboard <- -df$ykeyboard
keyboard$ycenter <- -keyboard$ycenter
df <- ComputeOffset(df, keyboard)
summary <- CrossValidationWithinUser(df, keyboard)

sink(output.file)
WriteTable(summary)
sink()

accuracy <- mean(summary$accuracy)
print(sprintf("Within user and with combined Gaussians: accuracy = %f",
      accuracy))
errors <- 1 - summary$accuracy
print(sprintf("error rate = %.5f, sd = %.5f", mean(errors), sd(errors)))
