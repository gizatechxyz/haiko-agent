use orion_numbers::{F64, F64Impl};

#[derive(Drop, Copy, PartialEq, Serde, Debug)]
pub enum Trend {
    Uptrend,
    Downtrend,
    Neutral
}

pub(crate) fn trend_classification(
    mut support_slopes: Span<F64>, mut resist_slopes: Span<F64>
) -> Span<Trend> {
    let max_delta = F64 { d: 42949673 }; // 0.01
    let mut sig = array![];

    loop {
        match support_slopes.pop_front() {
            Option::Some(support) => {
                let resist = *resist_slopes.pop_front().unwrap();

                if (*support > F64Impl::ZERO())
                    & (resist > F64Impl::ZERO())
                    & ((*support - resist).abs() < max_delta) {
                    sig.append(Trend::Uptrend);
                } else if (*support < F64Impl::ZERO())
                    & (resist < F64Impl::ZERO())
                    & ((*support - resist).abs() < max_delta) {
                    sig.append(Trend::Downtrend);
                } else {
                    sig.append(Trend::Neutral);
                };
            },
            Option::None => { break; },
        }
    };

    sig.span()
}

#[cfg(test)]
mod tests {
    use super::{trend_classification, Trend, F64};

    #[test]
    fn fit_trendlines_single_test() {
        let support_slopes = array![
            F64 { d: 90192756 },
            F64 { d: 70074756 },
            F64 { d: 36278332 },
            F64 { d: 4386582 },
            F64 { d: -24147317 },
            F64 { d: -118274243 },
            F64 { d: -127307758 },
            F64 { d: -184581893 },
            F64 { d: -204259213 },
            F64 { d: -229505288 },
            F64 { d: -273168185 },
            F64 { d: -214785012 },
            F64 { d: -163053865 },
            F64 { d: -163044633 }
        ]
            .span();

        let resist_slopes = array![
            F64 { d: 109242249 },
            F64 { d: 92864273 },
            F64 { d: 77375207 },
            F64 { d: 30595497 },
            F64 { d: -30349111 },
            F64 { d: -34401544 },
            F64 { d: -90022054 },
            F64 { d: -177505632 },
            F64 { d: -203517134 },
            F64 { d: -203530684 },
            F64 { d: -185200516 },
            F64 { d: -160111161 },
            F64 { d: -123531199 },
            F64 { d: -123521967 }
        ]
            .span();

        let category = trend_classification(support_slopes, resist_slopes);

        assert(*category.at(0) == Trend::Uptrend, 'wrong trend');
        assert(*category.at(1) == Trend::Uptrend, 'wrong trend');
        assert(*category.at(2) == Trend::Uptrend, 'wrong trend');
        assert(*category.at(3) == Trend::Uptrend, 'wrong trend');
        assert(*category.at(4) == Trend::Downtrend, 'wrong trend');
        assert(*category.at(5) == Trend::Neutral, 'wrong trend');
        assert(*category.at(6) == Trend::Downtrend, 'wrong trend');
        assert(*category.at(7) == Trend::Downtrend, 'wrong trend');
        assert(*category.at(8) == Trend::Downtrend, 'wrong trend');
        assert(*category.at(9) == Trend::Downtrend, 'wrong trend');
        assert(*category.at(10) == Trend::Neutral, 'wrong trend');
        assert(*category.at(11) == Trend::Neutral, 'wrong trend');
        assert(*category.at(12) == Trend::Downtrend, 'wrong trend');
        assert(*category.at(13) == Trend::Downtrend, 'wrong trend');
    }
}
