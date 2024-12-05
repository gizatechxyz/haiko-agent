mod volatility;
mod trend;
mod classification;

use orion_numbers::F64;
use trend::fit_trendlines_single;
use classification::{trend_classification, Trend};
use volatility::{calculate_volatility, volatility_to_limit};

#[derive(Drop, Serde)]
struct MarketAnalysis {
    trend: Trend,
    vol_limit: u32
}

#[derive(Serde, Drop)]
struct CairoRequest {
    prices: Span<F64>,
    lookback: u32,
}

fn serializer<T, +Serde<T>, +Drop<T>>(data: T) -> Array<felt252> {
    let mut output_array = array![];
    data.serialize(ref output_array);
    output_array
}

fn deserializer<T, +Serde<T>, +Drop<T>>(serialized: Array<felt252>) -> T {
    let mut span_array = serialized.span();
    Serde::<T>::deserialize(ref span_array).unwrap()
}


fn main(request: Array<felt252>) -> Array<felt252> {
    let deserialized = deserializer(request);
    let result = logic(deserialized);
    serializer(result)
}

fn logic(request: CairoRequest) -> MarketAnalysis {

    let mut support_slopes = array![];
    let mut resist_slopes = array![];

    let mut i = request.lookback - 1;

    while i < request.prices.len() {
        let ((support_coef, _), (resist_coef, _)) = fit_trendlines_single(
            request.prices.slice(i + 1 - request.lookback, request.lookback)
        );

        support_slopes.append(support_coef);
        resist_slopes.append(resist_coef);

        i += 1;
    };

    let trends = trend_classification(support_slopes.span(), resist_slopes.span());

    // Calculate volatility
    let std_vol = calculate_volatility(request.prices, false);

    // Calculate volatility limit
    let vol_limit = volatility_to_limit(std_vol);

    MarketAnalysis { trend: *trends[0], vol_limit }
}
