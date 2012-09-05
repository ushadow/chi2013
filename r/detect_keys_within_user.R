# Copyright 2012 Google Inc. All Rights Reserved.
# Author: yingyin@google.com (Ying Yin)
source('key_detection_lib.R')
source('analysis_lib.R')
source('cross_validation_lib.R')

args <- commandArgs(trailingOnly = T)

file <- args[1]
keyboard.file <- args[2]
user.file <- args[3]

df <- ReadData(file)
user.data <- ReadData(user.file)
df <- RemoveLeftHand(df, user.data)
df <- CombineIAndT(df)
keyboard <- ReadData(keyboard.file)

df$ykeyboard <- -df$ykeyboard
keyboard$ycenter <- -keyboard$ycenter
df <- ComputeOffset(df, keyboard)
summary <- CrossValidationWithinUser(df, keyboard)
print(summary)
accuracy <- mean(summary$accuracy)
print(sprintf("Within user and with combined Gaussians: accuracy = %f",
      accuracy))
