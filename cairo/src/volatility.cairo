use orion_numbers::{F64, F64Impl};

// Constants
const LOG_BASE: F64 = F64 { d: 42949 }; // ln(1.00001)
const SHIFT_AMOUNT: F64 = F64 { d: 33958695796736000 }; // 7_906_625;

// Function to convert standard volatility to limit
// limit = rounddown(log(1+vol)/log(1.00001)) + 7906625
pub(crate) fn volatility_to_limit(vol: F64) -> u32 {
    // Calculate the ratio
    let limit = (((F64Impl::ONE() + vol).ln() / LOG_BASE).floor()) + SHIFT_AMOUNT;

    limit.try_into().unwrap()
}

// https://quant.stackexchange.com/questions/60453/what-is-the-difference-between-log-volatility-and-simple-volatility-in-a-gbm
// Based on this Numpy implementation:
// returns_std = np.diff(prices) / prices[:-1]
// returns_log = np.log(np.array(prices[1:]) / np.array(prices[:-1]))
pub(crate) fn calculate_volatility(mut prices: Span<F64>, use_log: bool) -> F64 {
    let n_prices = prices.len();
    assert(n_prices >= 2, 'Need at least 2 prices');

    let mut returns = array![];
    let mut prev_price = *prices.pop_front().unwrap(); // Store first price
    loop {
        match prices.pop_front() {
            Option::Some(curr_price) => {
                if use_log {
                    // Log returns: ln(St/St-1)
                    returns.append((*curr_price / prev_price).ln())
                } else {
                    // Standard returns: (St - St-1)/St-1
                    returns.append((*curr_price - prev_price) / prev_price)
                }
                prev_price = *curr_price;
            },
            Option::None => { break; },
        }
    };

    let returns_span = returns.span();
    let n_returns = returns.len();

    let mean = mean(returns_span);

    let mut sum_squared_dev = F64Impl::ZERO();
    let mut returns_iter = returns.span();

    loop {
        match returns_iter.pop_front() {
            Option::Some(ret) => {
                let dev = *ret - mean;
                sum_squared_dev = sum_squared_dev + (dev * dev);
            },
            Option::None => { break; },
        }
    };

    let n_minus_one = F64Impl::new_unscaled((n_returns - 1).into());
    (sum_squared_dev / n_minus_one).sqrt()
}

fn mean(mut values: Span<F64>) -> F64 {
    let mut sum = F64Impl::ZERO();
    let n = F64Impl::new_unscaled(values.len().into());

    loop {
        match values.pop_front() {
            Option::Some(value) => { sum = sum + *value; },
            Option::None => { break; },
        };
    };

    sum / n
}

#[cfg(test)]
mod tests {
    use super::{calculate_volatility, F64};
    use orion_numbers::f64::helpers::assert_relative;

    #[test]
    fn test_volatility_calculation() {
        // Test prices: [8.0, 8.1, 8.3, 8.2, 8.4, 8.5, 8.3, 8.6]
        let prices = array![
            F64 { d: 34359738368 },
            F64 { d: 34789235098 },
            F64 { d: 35648228557 },
            F64 { d: 35218731827 },
            F64 { d: 36077725286 },
            F64 { d: 36507222016 },
            F64 { d: 35648228557 },
            F64 { d: 36936718746 }
        ]
            .span();

        let std_vol = calculate_volatility(prices, false);
        let log_vol = calculate_volatility(prices, true);

        // Expected NumPy values:
        // std_vol ≈ 0.02130856397892319
        // log_vol ≈ 0.021203085788001313

        let expected_std_vol = 91534336; // 0.02130856397892319
        let expected_log_vol = 91060096; // 0.021203085788001313

        assert_relative(std_vol, expected_std_vol, 'std vol matches numpy', Option::Some(429496));
        assert_relative(log_vol, expected_log_vol, 'log vol matches numpy', Option::Some(429496));
    }
}
