library(xts)
library(ggplot2)
library(mfGARCH)
library(gridExtra)

data <- r_midas_df

#change name of the Date column to date
names(data)[1] <- "date"
names(data)[3] <- 'RV.W'
names(data)[4] <- 'RV.M'


# transform the date and year month columns into date objects
data$date <- as.Date(data$date, format = "%Y-%m-%d")
data$year_month <- as.Date(paste0(format(data$date, "%Y"),"-",format(data$date, "%m"),"-01"))

# round PC1 and PC2 to  6 decimal places fo fix PC issue
data$PC1 <- round(data$PC1, 6)
data$PC2 <- round(data$PC2, 6)


test_size <- 173

##### MODEL FITTING #####

# fit a garch with mfgarch

garch_midas_RV_PC2 <- fit_mfgarch(data,
                                  y = "r",
                                  x = "RV.M",
                                  K = 1,
                                  low.freq = "year_month",
                                  var.ratio.freq = "year_month",
                                  gamma = TRUE,
                                  x.two = "PC2",
                                  K.two = 1,
                                  low.freq.two = "year_month")

# plot the results
plot(garch_midas_RV_PC2)

#plot RV W
plot(data$RV.W, type = "l", col = "blue", ylab = "RV.W", xlab = "Date", main = "RV.W")

# calculate tau * g from the garch_midas_RV_PC2 object
dongle <- sqrt(garch_midas_RV_PC2[["tau"]] * garch_midas_RV_PC2[["g"]])

# plot RV W and tau * g
plot(data$RV.W, type = "l", col = "blue", ylab = "RV.W", xlab = "Date", main = "RV.W")
lines(dongle, col = "red")

predictions <- predict(garch_midas_RV_PC2, horizon = 1)

##### PREDICTIONS #####

rolling_forecast <- function(data, test_size) {
  
  rolling_predictions <- numeric(test_size)
  
  # Loop over the test set
  for (i in 1:test_size) {
    print(i)
    # Define the training set
    train <- head(data, -test_size + i - 1)
    
    # Fit the model
    model_fit <- fit_mfgarch(train,
                             y = "r",
                             x = "RV.M",
                             K = 1,
                             low.freq = "year_month",
                             var.ratio.freq = "year_month",
                             gamma = TRUE,
                             x.two = "PC1",
                             K.two = 1,
                             low.freq.two = "year_month")
    
    # Forecast the next step
    forecast <- predict(model_fit, horizon = 1)
    
    # Extract the forecasted variance and take the square root for the standard deviation
    rolling_predictions[i] <- sqrt(forecast)
  }
  
  # Convert predictions to a time series object
  return(rolling_predictions)
}

# Example usage:
# Assuming `data` is an xts or zoo object containing your time series data and `test_size` is the number of rolling forecasts you want to make.
# rolling_garch_forecast(data, test_size)

gm_pc1_forecasts <- rolling_forecast(data, test_size)

df <- data.frame(gm_forecasts)

# Write the data frame to a CSV file
write.csv(df, file = "gm_forecasts.csv", row.names = FALSE)