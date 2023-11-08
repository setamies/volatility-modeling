library(rugarch)
library(xts)
library(ggplot2)
library(mfGARCH)
library(gridExtra)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))


##### LOAD AND FORMAT DATA #####


data <- read.csv("sp500_weekly.csv")

# transform the date column into date objects
data$Date <- as.Date(data$Date, format = "%Y-%m-%d")

# compute realised volatility from squared returns
data$RV <- sqrt(data$Squared.Return)

# create an xts object of the log returns indexed by the date
returns_indexed <- xts(data$Log.Return, order.by = data$Date)

test_size <- 173

##### SPECIFY MODELS #####

garch_spec <- ugarchspec(
  variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model = list(armaOrder = c(0, 0), include.mean = FALSE),
  distribution.model = "norm"
)

egarch_spec <- ugarchspec(
  variance.model = list(model = "eGARCH", garchOrder = c(1, 1)),
  mean.model = list(armaOrder = c(0, 0), include.mean = FALSE),
  distribution.model = "norm"
)

gjr_spec <- ugarchspec(
  variance.model = list(model = "gjrGARCH", garchOrder = c(1, 1)),
  mean.model = list(armaOrder = c(0, 0), include.mean = FALSE),
  distribution.model = "norm"
)

##### FIT MODELS #####
garch_fit <- ugarchfit(
  spec = garch_spec,
  data = returns_indexed,
  out.sample = test_size,
  solver = "hybrid"
)

egarch_fit <- ugarchfit(
  spec = egarch_spec,
  data = returns_indexed,
  out.sample = test_size,
  solver = "hybrid"
)

gjr_fit <- ugarchfit(
  spec = gjr_spec,
  data = returns_indexed,
  out.sample = test_size,
  solver = "hybrid"
)

# extract the fitted values from the fitted objects
garch_fitted <- sigma(garch_fit)
egarch_fitted <- sigma(egarch_fit)
gjr_fitted <- sigma(gjr_fit)

# create a dataframe for fitted values
in_sample_df <- data.frame(
  garch_fitted,
  egarch_fitted,
  gjr_fitted,
  data$RV[1:(nrow(data) - test_size)]
)
colnames(in_sample_df) <- c("GARCH", "EGARCH", "GJR", "RV")

##### OUT-OF-SAMPLE FORECASTS #####
garch_forecast <- ugarchforecast(garch_fit,
                                 n.ahead = 1,
                                 n.roll = test_size,
                                 out.sample = test_size)

egarch_forecast <- ugarchforecast(
  egarch_fit,
  n.ahead = 1,
  n.roll = test_size,
  out.sample = test_size
)

gjr_forecast <- ugarchforecast(gjr_fit,
                               n.ahead = 1,
                               n.roll = test_size,
                               out.sample = test_size)

# extract the forecasts from the forecast objects
garch_predictions <- sigma(garch_forecast)
egarch_predictions <- sigma(egarch_forecast)
gjr_predictions <- sigma(gjr_forecast)


# create a dataframe for out of sample values
out_of_sample_df <- data.frame(
  t(garch_predictions),
  t(egarch_predictions),
  t(gjr_predictions),
  data$RV[(nrow(data) - test_size):nrow(data)]
)

colnames(out_of_sample_df) = c("GARCH", "EGARCH", "GJR", "RV")

###### PLOT PREDICTIONS #####

# plot the garch vs RV from the xts object as overlapping time series using ggplot
garch_plot <-
  ggplot(data = out_of_sample_df, aes(x = index(out_of_sample_df))) +
  geom_line(aes(y = garch_predictions, colour = "GARCH")) +
  geom_line(aes(y = RV, colour = "RV")) +
  scale_colour_manual(name = NULL,
                      values = c("GARCH" = "red", "RV" = "blue")) +
  labs(title = "GARCH vs RV", x = "Date", y = "Volatility") +
  theme(legend.position = "bottom")

egarch_plot <-
  ggplot(data = out_of_sample_df, aes(x = index(out_of_sample_df))) +
  geom_line(aes(y = egarch_predictions, colour = "EGARCH")) +
  geom_line(aes(y = RV, colour = "RV")) +
  scale_colour_manual(name = NULL,
                      values = c("EGARCH" = "red", "RV" = "blue")) +
  labs(title = "EGARCH vs RV", x = "Date", y = "Volatility") +
  theme(legend.position = "bottom")

gjr_plot <-
  ggplot(data = out_of_sample_df, aes(x = index(out_of_sample_df))) +
  geom_line(aes(y = gjr_predictions, colour = "GJR-GARCH")) +
  geom_line(aes(y = RV, colour = "RV")) +
  scale_colour_manual(name = NULL,
                      values = c("GJR-GARCH" = "red", "RV" = "blue")) +
  labs(title = "GJR-GARCH vs RV", x = "Date", y = "Volatility") +
  theme(legend.position = "bottom")


