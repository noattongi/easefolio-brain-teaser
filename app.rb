require 'sinatra'

########################################################

#Jupiter Fund

########################################################

def nominal_profit(capital, rate, years)
  ((capital * (1 + rate) ** years) - capital).round(2)
end

def real_profit(capital, rate, years, risk_free_rate)
  (nominal_profit(capital, rate, years) - nominal_profit(capital, risk_free_rate, years)).round(2)
end

def real_profit_adjusted_for_inflation(capital, rate, years, risk_free_rate, inflation_rate)
  (real_profit(capital, rate, years, risk_free_rate) / (1 + inflation_rate) ** years).round(2)
end

post '/' do
  @capital = params[:capital] || 100000000.00
  @rate = params[:rate] || 0.15
  @years = params[:years] || 10
  @num_of_investors = params[:num_of_investors] || 100
  redirect "/?capital=#{@capital}&rate=#{@rate}&years=#{@years}&num_of_investors=#{@num_of_investors}"
end

get '/' do
  @capital = params[:capital] ? params[:capital].to_f : 100000000.00
  @selected_rate = params[:rate] ? params[:rate].to_f : 0.15
  @years = params[:years] ? params[:years].to_i : 10
  @num_of_investors = params[:num_of_investors] ? params[:num_of_investors].to_i : 100
  @bull_rate = 0.21
  @base_rate = 0.15
  @bear_rate = 0.09
  @risk_free_rate = 0.10
  @inflation_rate = 0.03

  #1.a
  @nominal_profit = nominal_profit(@capital, @selected_rate, @years)
  @real_profit = real_profit(@capital, @selected_rate, @years, @risk_free_rate)
  @real_profit_adjusted_for_inflation = real_profit_adjusted_for_inflation(@capital, @selected_rate, @years, @risk_free_rate, @inflation_rate)

  #1.b
  @bull_moic = ((1 + @bull_rate) ** @years).round(2)
  @base_moic = ((1 + @base_rate) ** @years).round(2)
  @bear_moic = ((1 + @bear_rate) ** @years).round(2)

  #1.c
  remaining = 500000000.00
  @investor_take = 0.00
  @gp_take = 0.00

  #hurdle 1
  hurdle1 = @capital * 1.8

  #take the rest of remaining if its less than hurdle1
  if remaining < hurdle1
    @investor_take = @investor_take + remaining
    remaining = 0.00
  else #otherwise take full hurdle1 amount
    @investor_take = @investor_take + hurdle1
    remaining = remaining - hurdle1
  end

  #hurdle 2
  unless remaining <= 0.00
    #calculate how much in this tranche
    hurdle2 = @capital * 2.7
    hurdle2_tranche = hurdle2 - hurdle1
    #GP fee is 20% over the first hurdle
    if hurdle2_tranche > remaining
      @gp_take = @gp_take + (remaining * 0.20)
      @investor_take = @investor_take + (remaining * 0.80)
      remaining = 0.00
    else
      @gp_take = @gp_take + (hurdle2_tranche * 0.20)
      @investor_take = @investor_take + (hurdle2_tranche * 0.80)
      remaining = remaining - hurdle2_tranche
    end
  end

  #GP fee is 30% over the second hurdle
  gp_fees_hurdle2 = remaining * 0.30
  remaining = remaining - gp_fees_hurdle2
  @gp_take = @gp_take + gp_fees_hurdle2

  #remaining to investors
  @investor_take = @investor_take + remaining

  erb :index, locals: {
    capital: @capital,
    selected_rate: @selected_rate,
    years: @years,
    nominal_profit: @nominal_profit,
    real_profit: @real_profit,
    real_profit_adjusted_for_inflation: @real_profit_adjusted_for_inflation,
    bull_moic: @bull_moic,
    base_moic: @base_moic,
    bear_moic: @bear_moic,
    investor_take: @investor_take,
    num_of_investors: @num_of_investors,
    gp_take: @gp_take,
  }
end




########################################################

#Venus Fund

########################################################

def update_positions_with_asset_prices(positions, prices, date)
  positions.each do |position|
    asset_price_entry = prices.find{|price| price[:asset] == position[:asset]}
    if asset_price_entry
      position[:updated_on] = date
      position[:price] = asset_price_entry[:price]
      position[:value] = position[:amount] * asset_price_entry[:price]
    end
  end
  positions
end

def venus_waterfall(investor_working_capital, total_working_capital, years, withdrawal_pct, fund_nav)
  total_withdrawal = ((investor_working_capital / total_working_capital) * fund_nav * withdrawal_pct).round(2)
  investor_take = 0.00
  gp_take = 0.00
  remaining = total_withdrawal
  #Hurdle 1
  hurdle1 = investor_working_capital * withdrawal_pct * (1.1 ** years).round(2)
  if remaining < hurdle1
    investor_take = remaining
    remaining = 0.00
  else
    investor_take = hurdle1
    remaining = remaining - hurdle1
  end
  #Hurdle 2
  unless remaining <= 0.00
    hurdle2 = investor_working_capital * withdrawal_pct * (1.27 ** years).round(2)
    hurdle2_tranche = hurdle2 - hurdle1
    if hurdle2_tranche > remaining
      gp_take = remaining * 0.20
      investor_take = investor_take + (remaining * 0.80)
      remaining = 0.00
    else
      gp_take = gp_take + (hurdle2_tranche * 0.20)
      investor_take = investor_take + (hurdle2_tranche * 0.80)
      remaining = remaining - hurdle2_tranche
    end
  end

  #GP fee is 30% over the second hurdle
  gp_fees_hurdle2 = remaining * 0.30
  remaining = remaining - gp_fees_hurdle2
  gp_take = gp_take + gp_fees_hurdle2
  #Remaining to investor
  investor_take = investor_take + remaining
  [investor_take, gp_take]
end

post '/venus' do
  @investor1_working_capital = params[:investor1_working_capital] || 100000.00
  @investor2_working_capital = params[:investor2_working_capital] || 100000.00
  @investor3_working_capital = params[:investor3_working_capital] || 100000.00
  redirect "/venus?investor1_working_capital=#{@investor1_working_capital}&investor2_working_capital=#{@investor2_working_capital}&investor3_working_capital=#{@investor3_working_capital}"
end

get '/venus' do
  venus_positions = [];
  #2017
  #starting with 3 investors at $100k each, no assets yet
  investors = [
    {
      id: 1,
      working_capital: params[:investor1_working_capital].to_f || 100000.00,
    },
    {
      id: 2,
      working_capital: params[:investor2_working_capital].to_f || 100000.00,
    },
    {
      id: 3,
      working_capital: params[:investor3_working_capital].to_f || 100000.00,
    },
  ]

  #2018
  #Purchase $250K worth of BTC on 1-15-18 @ $13767.30
  venus_position_1 = {
    created_on: "1-15-18",
    updated_on: "1-15-18",
    asset: "BTC",
    value: 250000.00,
    price: 13767.30,
    amount: 18.16,
  }
  venus_positions << venus_position_1

  #2019
  #2 investors join with $100k each
  investors << {
    id: 4,
    working_capital: 100000.00,
  }
  investors << {
    id: 5,
    working_capital: 100000.00,
  }

  #Purchase $150K worth of ETH on 1-15-19 @ $129.17 & $100K worth of TSLA on 5-17-19 @ $14.37
  venus_position_2 = {
    created_on: "1-15-19",
    updated_on: "1-15-19",
    asset: "ETH",
    value: 150000.00,
    price: 129.17,
    amount: 1161.26,
  }
  venus_position_3 = {
    created_on: "5-17-19",
    updated_on: "5-17-19",
    asset: "TSLA",
    value: 100000.00,
    price: 14.37,
    amount: 6958.94,
  }
  venus_positions << venus_position_2
  venus_positions << venus_position_3

  #2020
  #Investor #1 removes 100% of their investment and #2 removes 50% on 2-10-20
  # Asset values on 2-10-20
  asset_prices_2_10_20 = [
    {
      asset: "BTC",
      price: 10115.56,
    },
    {
      asset: "ETH",
      price: 228.55,
    },
    {
      asset: "TSLA",
      price: 53.33,
    },
  ]
  #update positions with asset prices
  venus_positions = update_positions_with_asset_prices(venus_positions, asset_prices_2_10_20, "2-10-20")
  venus_nav = venus_positions.sum{|position| position[:value]}

  #First we calculate each investor's share of the NAV that is being withdrawn
  total_working_capital = investors.sum{|investor| investor[:working_capital]}
  investor1 = investors[0]
  investor2 = investors[1]
  #Waterfalls, 10%/27% hurdles over 2 years
  investor1_take, investor1_gp_take = venus_waterfall(investor1[:working_capital], total_working_capital, 2, 1.00, venus_nav.round(2)) #venus_waterfall function written on line 115
  investor2_take, investor2_gp_take = venus_waterfall(investor2[:working_capital], total_working_capital, 2, 0.50, venus_nav.round(2))

  erb :venus, locals: {
    investors: investors,
    venus_positions: venus_positions,
    venus_nav: venus_nav,
    asset_prices_2_10_20: asset_prices_2_10_20,
    investor1_take: investor1_take.round(2),
    investor1_gp_take: investor1_gp_take.round(2),
    investor2_take: investor2_take.round(2),
    investor2_gp_take: investor2_gp_take.round(2),
  }
end
