import pandas as pd
import yfinance as yf
import numpy as np

class StockData:
    def __init__(self, ticker, start='2010-01-01', end='2022-12-31'):
        self.ticker = ticker
        self.start = start
        self.end = end
        self.data = self.fetch_stock_data()

    def fetch_stock_data(self):
        # Fetch stock data for the given ticker and date range.
        stock_data = yf.download(self.ticker, start=self.start, end=self.end)
        return stock_data

    def calculate_daily_return(self):
        # Calculate the daily returns as the changes in closing prices (Adj Close).
        self.data['Daily Return'] = self.data['Adj Close'].pct_change()

    def calculate_log_return(self):
        # Could also calculate as the differnece in returns
        self.data['Log Return'] = np.log(self.data['Adj Close'] / self.data['Adj Close'].shift(1)) * 100

    def calculate_squared_return(self):
        # Proxy for realized variance
        self.data['Squared Return'] = self.data['Log Return']**2

    def format_date(self):
        # Format the date column to be YYYY-MM-DD
        self.data.reset_index(inplace=True)
        self.data['Date'] = self.data['Date'].dt.strftime('%Y-%m-%d')

    def choose_data(self, columns):
        # Choose only the specified columns
        self.data = self.data[columns]

    def set_date_as_index(self):
        # Set the date column as the index
        self.data.set_index('Date', inplace=True)
        # Turn the index to datetime
        self.data.index = pd.to_datetime(self.data.index)

    def fetch_data(self):
        """
        Run all calculations on the fetched data.
        """
        self.format_date()
        self.calculate_daily_return()
        self.calculate_log_return()
        self.calculate_squared_return()
        self.choose_data(['Date', 'Log Return', 'Squared Return'])
        self.set_date_as_index()
        return self.data
