mod trend;
mod classification;

use orion_numbers::F64;
use trend::fit_trendlines_single;
use classification::{trend_classification, Trend};

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

fn logic(data: Span<F64>) -> Span<Trend> {
    let lookback = 14;

    let mut support_slopes = array![];
    let mut resist_slopes = array![];

    let mut i = lookback - 1;
    while i < lookback {
        let ((support_coef, _), (resist_coef, _)) = fit_trendlines_single(
            data.slice(i + 1 - lookback, lookback)
        );

        support_slopes.append(support_coef);
        resist_slopes.append(resist_coef);

        i += 1;
    };

    trend_classification(support_slopes.span(), resist_slopes.span())
}
