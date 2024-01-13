import pandas as pd
import yfinance as yf

def to_timezone_naive(datetime_series):
    return datetime_series.dt.tz_localize(None)

def get_month_end_data(df, date_column='Date'):
    df = df.copy()
    df[date_column] = to_timezone_naive(pd.to_datetime(df[date_column]))
    df = df.sort_values(by=date_column)
    df['YearMonth'] = df[date_column].dt.to_period('M')
    monthly_df = df.groupby('YearMonth').last()
    monthly_df.reset_index(inplace=True)
    monthly_df[date_column] = monthly_df['YearMonth'].dt.strftime('%Y-%m')
    monthly_df.drop('YearMonth', axis=1, inplace=True)
    return monthly_df

def download_and_process_financial_data(ticker, start_date, end_date, column_name):
    data = yf.download(ticker, start=start_date, end=end_date)['Close'].reset_index()
    data = get_month_end_data(data)
    data = data.rename(columns={'Close': column_name})

    if column_name == '3 Month T-Bill Rate':
        data[column_name] = data[column_name].diff()

    return data

def calculate_yield_curve_slope(tbill_3_month, tbill_10_yr):
    ycurve_slope = tbill_10_yr['10 Year T-Bill Rate'] - tbill_3_month['3 Month T-Bill Rate']

    yield_curve_df = pd.DataFrame({'Date': tbill_3_month['Date'], 'Yield Curve Slope': ycurve_slope})

    yield_curve_df['Yield Curve Slope'] = yield_curve_df['Yield Curve Slope'].diff()

    return yield_curve_df

def process_reer_data(filepath):
    reer_data = pd.read_excel(filepath, header=10)
    reer_data = reer_data[['observation_date', 'RBUSBIS']].rename(columns={'observation_date': 'Date'})
    reer_data['Reer Change'] = reer_data['RBUSBIS'].pct_change()
    return get_month_end_data(reer_data, 'Date')[['Date', 'Reer Change']]

def process_cpi_data(filepath):
    cpi_data = pd.read_csv(filepath)
    cpi_data = cpi_data[cpi_data['LOCATION'] == 'USA']
    cpi_data = cpi_data.rename(columns={'TIME': 'Date', 'Value': 'CPI'})
    cpi_data = get_month_end_data(cpi_data[['Date', 'CPI']], 'Date')
    cpi_data['CPI'] = cpi_data['CPI'].diff()
    return cpi_data

# Download and process financial data
short_term_interest = download_and_process_financial_data('^IRX', '2005-12-01', '2023-08-01', '3 Month T-Bill Rate')
long_term_interest = download_and_process_financial_data('^TNX', '2005-12-01', '2023-08-01', '10 Year T-Bill Rate')
oil_price = download_and_process_financial_data('CL=F', '2005-12-01', '2023-08-01', 'Oil Price')
oil_price['Change Oil Price'] = oil_price['Oil Price'].pct_change()

# Calculate the yield curve slope
ycurve_slope = calculate_yield_curve_slope(short_term_interest, long_term_interest)

# Process REER and CPI data
reer_data = process_reer_data('data/dollar_reer.xls')
us_cpi_data = process_cpi_data('data/cpi.csv')

# Process Unemployment Rate data
unemp_data = pd.read_csv('data/unemp.csv', sep=';')[['Period', 'Value']]
unemp_data = unemp_data[:-1]
unemp_data = (unemp_data.rename(columns={'Period': 'Date', 'Value': 'Unemployment Rate'})
                        .assign(Date=lambda df: pd.to_datetime(df['Date']),
                                Unemployment_Rate=lambda df: df['Unemployment Rate'].astype(float))
                        .sort_values('Date')
                        .assign(Unemployment_Rate_Change=lambda df: df['Unemployment_Rate'].pct_change())
                        .dropna()
                        .pipe(get_month_end_data, 'Date')
                        .rename(columns={'Unemployment_Rate_Change': 'Unemployment Rate Change'})
                        [['Date', 'Unemployment Rate Change']]) 

# Merge all dataframes on the Date column
macro_df = (short_term_interest.merge(ycurve_slope, on='Date', how='left')
                               .merge(reer_data, on='Date', how='left')
                               .merge(oil_price[['Date', 'Change Oil Price']], on='Date', how='left')
                               .merge(us_cpi_data, on='Date', how='left')
                               .merge(unemp_data, on='Date', how='left')
                               .dropna()
                               .rename(columns={'Date': 'Year-Month'}))

# Save the macro data to a csv file
macro_df.to_csv('data/macro_data.csv', index=False)