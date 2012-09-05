# Copyright 2012 Google Inc. All Rights Reserved.
# Author: yingyin@google.com (Ying Yin)
source('key_detection_lib.R')
source('analysis_lib.R')
source('cross_validation_lib.R')

args <- commandArgs(trailingOnly = T)

data.file <- args[1]
user.file <- args[2]
keyboard.file <- args[3]
output.file <- args[4]

df <- ReadData(data.file)
user.data <- ReadData(user.file)
keyboard <- ReadData(keyboard.file)
# Invert y coordinates.
df$ykeyboard <- -df$ykeyboard
keyboard$ycenter <- -keyboard$ycenter

df <- CombineIAndT(df)
df <- RemoveLeftHand(df, user.data)
df <- ComputeOffset(df, keyboard)

res.posture.key <- CrossValidation(df, keyboard, EvalKeyDetectionByPostureByKey,
    verbose = F)
ag <- aggregate(list(accuracy = res.posture.key$accuracy),
                list(key = res.posture.key$key), mean)
res.combined <- CrossValidation(df, keyboard, EvalKeyDetection)
ag$combined.accuracy <- mean(res.combined$accuracy)
ag$sig <- ag$accuracy > ag$combined.accuracy
sink(output.file)
WriteTable(ag)
sink()
