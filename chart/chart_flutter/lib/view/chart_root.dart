import 'package:chartlib/chartlib.dart';
import 'package:chartwidget/chartwidget.dart';
import 'package:flutter/material.dart';

import '../interop/chart_interop.dart';

/// Root widget that renders the chart based on the latest ViewModel state
/// received from the Vue shell via JS interop.
class ChartRoot extends StatefulWidget {
  const ChartRoot({super.key, required this.interop});

  final ChartInterop interop;

  @override
  State<ChartRoot> createState() => _ChartRootState();
}

class _ChartRootState extends State<ChartRoot> {
  late final CandleStudy _candleStudy = CandleStudy();
  late final List<Study<dynamic>> _overlayStudies = <Study<dynamic>>[
    SMAStudy(period: 20, color: '#ff9800'),
    EMAStudy(period: 12, color: '#4caf50'),
    BollingerBandsStudy(
      period: 20,
      multiplier: 2,
      fillColor: '#2196f3',
      borderColor: '#2196f3',
    ),
    LastPriceLineStudy(),
  ];
  late final List<SubPaneConfig> _subPanes = <SubPaneConfig>[
    SubPaneConfig(
      id: 'volume',
      primaryStudy: VolumeStudy(),
      heightPercent: 0.25,
    ),
    SubPaneConfig(id: 'rsi', primaryStudy: RSIStudy(), heightPercent: 0.25),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChartViewModel?>(
      valueListenable: widget.interop.viewModel,
      builder: (context, viewModel, _) {
        if (viewModel == null) {
          final theme = Theme.of(context);
          return Center(
            child: Text(
              'Awaiting chart data from Vue...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final chartTheme = viewModel.theme;

        return Container(
          color: chartTheme.colors.background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ChartWidget(
            key: ValueKey('chart-${viewModel.revision}'),
            dataManager: viewModel.dataManager,
            candleStudy: _candleStudy,
            overlayStudies: _overlayStudies,
            subPanes: _subPanes,
            theme: chartTheme,
            onChartInitialized: widget.interop.onChartInitialized,
          ),
        );
      },
    );
  }
}
