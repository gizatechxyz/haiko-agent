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
