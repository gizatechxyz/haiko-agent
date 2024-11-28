use orion_numbers::f64::{F64, F64Impl};
use orion_data_structures::span::SpanMathTrait;
use orion_algo::linear_fit::linear_fit;


/// Assesses a candidate trend line by computing the sum of squared differences
/// between the fitted line and the data, returning a negative value if invalid.
/// Used by the optimising function `optimise_slope`.
///
/// Parameters
/// ----------
/// support : bool
///    Whether trend line is support (lower) or resistance (upper) trend
/// pivot : usize
///    Pivot point index
/// slope : F64
///    Slope of the trendline to test
/// y : Span<F64>
///    Array of prices
///
fn check_trend_line(support: bool, pivot: usize, slope: F64, mut y: Span<F64>) -> F64 {
    // Find the intercept of the line going through pivot point with given slope.
    let intercept = (F64 { d: -slope.d } * pivot.into()) + *y[pivot];
    let mut diffs: Array<F64> = array![];
    let mut max_diff = F64Impl::MIN();
    let mut min_diff = F64Impl::MAX();

    let mut i = 0;
    while i != y.len() {
        let line_val = (slope * i.into()) + intercept;
        let diff = line_val - *y.pop_front().unwrap();
        diffs.append(diff);

        if diff > max_diff {
            max_diff = diff;
        };
        if diff < min_diff {
            min_diff = diff
        };

        i += 1;
    };

    // Check to see if the line is valid, return -1 if it is not valid.
    if support && (max_diff > F64 { d: 42950 // 1e-5
     }) {
        return F64 { d: -4294967296 }; // -1.0
    } else if !support && (min_diff < F64 { d: -42950 // 1e-5
     }) {
        return F64 { d: -4294967296 }; // -1.0
    };

    // Squared sum of diffs between data and line
    sse(diffs.span())
}

fn sse(mut arr: Span<F64>) -> F64 {
    let mut err = F64Impl::ZERO();

    loop {
        match arr.pop_front() {
            Option::Some(ele) => { err = err + (*ele * *ele); },
            Option::None => { break; },
        }
    };

    err
}

/// Minimises the sum of squared differences between the fitted line and the data
/// with gradient descent.
///
/// Parameters
/// ----------
/// support : bool
///     Whether trend line is support (lower) or resistance (upper) trend
/// pivot : usize
///     Pivot point index
/// init_slope : F64
///     Initial slope value of trendline to optimise
/// y : Span<F64>
///     Array of prices
fn optimise_slope(support: bool, pivot: usize, init_slope: F64, y: Span<F64>) -> (F64, F64) {
    // Amount to change slope by for each iteration.
    let slope_unit = (y.max() - y.min()) / F64Impl::new_unscaled(y.len().into());

    // Optimisation parameters
    // `opt_step` will decrease toward `min_step` as the optimisation progresses.
    // TODO: Conduct sensitivity analysis to find optimal values.
    let opt_step = F64Impl::ONE(); // Starting step size.
    let min_step = F64 { d: 429497 }; // Minimum step size 0.0001.
    let mut curr_step = opt_step; // Current step size

    // Initiate at the slope of the line of best fit and find the error, which will
    // be minimised by comparison to residual errors from alternative slopes.
    let mut best_slope = init_slope;
    let mut best_err = check_trend_line(support, pivot, init_slope, y);
    assert(best_err >= F64Impl::ZERO(), 'best error <= 0');

    // Run gradient descent by numerical differentiation. To find the direction of
    // change, we increase the slope by a very small amount and see if the error
    // increases or decreases. This informs the direction of change in slope.
    let mut get_derivative = true;
    let mut derivative: F64 = F64Impl::ZERO();

    while curr_step > min_step {
        // Find derivative and direction of change.
        if get_derivative {
            // Change slope by small amount (`min_step`) and compare errors to existing
            // slope to find derivative and direction of change.
            let mut slope_change = best_slope + (slope_unit * min_step);
            let mut test_err = check_trend_line(support, pivot, slope_change, y);
            derivative = test_err - best_err;

            // If increasing by a small amount fails, try decreasing by a small amount.
            // This is the same computation as above, but with an inverse sign.
            if test_err < F64Impl::ZERO() {
                slope_change = best_slope - slope_unit * min_step;
                test_err = check_trend_line(support, pivot, slope_change, y);
                derivative = best_err - test_err;
            }

            // Derivative failed, give up and panic.
            assert(test_err > F64Impl::ZERO(), 'Derivative failed.');

            // Direction found. We set `get_derivative` to `False` to start the optimisation.
            get_derivative = false;
        }

        // Increase or decrease slope based on derivative.
        let test_slope = if derivative > F64Impl::ZERO() {
            best_slope - (slope_unit * curr_step)
        } else {
            best_slope + (slope_unit * curr_step)
        };

        // Check impact on error.
        // If the new slope value created invalid trendline or did not reduce the error
        // in the data, we reduce the step size and try again. Otherwise, we update the
        // best slope and error and find the next derivative.
        let test_err = check_trend_line(support, pivot, test_slope, y);
        if (test_err < F64Impl::ZERO()) || (test_err >= best_err) {
            curr_step *= F64Impl::HALF();
        } else {
            best_err = test_err;
            best_slope = test_slope;
            get_derivative = true // Recompute derivative
        }
    };

    return (best_slope, (-best_slope * pivot.into()) + *y[pivot]);
}

/// Fits trendlines over array of close prices.
///
/// This model tends to better control for outliers, as it ignores the candlestick extremes.
///
/// Parameters
/// ----------
/// data : Span<F64>
///     Array of closing prices
///
fn fit_trendlines_single(mut data: Span<F64>) -> ((F64, F64), (F64, F64)) {
    // Find line of best fit (slope and intercept) over close prices with OLS estimator.
    //   coefs[0] = slope, coefs[1] = intercept
    let mut x: Span<F64> = SpanMathTrait::arange(data.len());

    let (coef_a, coef_b) = linear_fit(x, data);

    // Get predicted line of fit.
    let mut line_points: Array<F64> = array![];
    loop {
        match x.pop_front() {
            Option::Some(x_ele) => { line_points.append((coef_a * *x_ele) + coef_b) },
            Option::None => { break; },
        }
    };

    // Find upper and lower pivot points.
    // These are the points where the delta between the data and the line of
    // best fit are maximised / minimised.
    let mut upper_pivot: usize = 0;
    let mut lower_pivot: usize = 0;
    let mut i: usize = 0;
    let mut upper_delta = F64Impl::MIN();
    let mut lower_delta = F64Impl::MAX();
    let data_copy = data;
    loop {
        match data.pop_front() {
            Option::Some(data_ele) => {
                let delta = *data_ele - line_points.pop_front().unwrap();

                if delta > upper_delta {
                    upper_delta = delta;
                    upper_pivot = i;
                }

                if delta < lower_delta {
                    lower_delta = delta;
                    lower_pivot = i;
                }

                i += 1;
            },
            Option::None => { break; },
        }
    };

    // Optimise the slope for support and resistance trend lines.
    let support_coefs = optimise_slope(true, lower_pivot, coef_a, data_copy);
    let resist_coefs = optimise_slope(false, upper_pivot, coef_a, data_copy);

    return (support_coefs, resist_coefs);
}

#[cfg(test)]
mod tests {
    use super::{check_trend_line, optimise_slope, fit_trendlines_single, F64};
    use orion_numbers::f64::helpers::{assert_precise, assert_relative};

    #[test]
    fn fit_trendlines_single_test() {
        let data = array![
            F64 { d: 34307864436 }, //7.987922159023583
            F64 { d: 34317942637 },
            F64 { d: 34967382307 },
            F64 { d: 34717645274 },
            F64 { d: 35085779617 },
            F64 { d: 35040253046 },
            F64 { d: 35030342691 },
            F64 { d: 35532887880 },
            F64 { d: 35545139375 },
            F64 { d: 35568048422 },
            F64 { d: 35811476431 },
            F64 { d: 35432070807 },
            F64 { d: 35310094099 },
            F64 { d: 35708260430 },
        ]
            .span();

        let slope_support_expected = 90192756;
        let slope_resist_expected = 109242249;

        let ((slope_support_actual, _), (slope_resist_actual, _)) = fit_trendlines_single(data);
        assert_relative(
            slope_support_actual,
            slope_support_expected,
            'best_slopes should be equal',
            Option::Some(429496730)
        );
        
        assert_relative(
            slope_resist_actual,
            slope_resist_expected,
            'best_slopes should be equal',
            Option::Some(429496730)
        );
    }
}
