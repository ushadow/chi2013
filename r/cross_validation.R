# Copyright 2012 Google Inc. All Rights Reserved.
# Author: yingyin@google.com (Ying Yin)
source('key_detection_lib.R')
source('analysis_lib.R')
source('cross_validation_lib.R')
source('key_model_lib.R')

args <- commandArgs(trailingOnly = T)

data.file <- args[1]
user.file <- args[2]
keyboard.file <- args[3]
output.file <- args[4]
fun <- args[5]

df <- ReadData(data.file)
user.data <- ReadData(user.file)
keyboard <- ReadData(keyboard.file)
# Invert y coordinates.
df$ykeyboard <- -df$ykeyboard
keyboard$ycenter <- -keyboard$ycenter

df <- ComputeOffset(df, keyboard)
df <- CombineIAndT(df)

res <- CrossValidation(df, keyboard, fun, verbose = T)
ag <- ddply(res, .(user_id), EvalUserResult)
sink(output.file)
WriteTable(ag)
sink()

print(sprintf("Over all accuracy = %.5f", mean(ag$accuracy)))
