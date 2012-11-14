# Copyright 2012 Google Inc. All Rights Reserved.
# Author: yingyin@google.com (Ying Yin)
#
# Cross validation on the posture adaption accuracy.

source('key_detection_lib.R')
source('analysis_lib.R')
source('cross_validation_lib.R')

args <- commandArgs(trailingOnly = T)

data.file <- args[1]
user.file <- args[2]
keyboard.file <- args[3]

df <- ReadData(data.file)
user.data <- ReadData(user.file)
keyboard <- ReadData(keyboard.file)
# Invert y coordinates.
df$ykeyboard <- -df$ykeyboard
keyboard$ycenter <- -keyboard$ycenter

df <- CombineIAndT(df)
df <- RemoveLeftHand(df, user.data)
df <- ComputeOffset(df, keyboard)

#res.posture.key <- CrossValidation(df, keyboard, EvalKeyDetectionByPostureByKey)
#ag <- aggregate(list(accuracy = res.posture.key$accuracy),
#                list(key = res.posture.key$key), mean)
#print(ag)

plot.name <- sprintf('out/analysis/%s-barplot.png', FileBaseName(data.file))
CrossValidationPosture(df, keyboard, plot.name)


