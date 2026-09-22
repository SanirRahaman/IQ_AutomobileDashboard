final class InsightEngineConfig {
  const InsightEngineConfig({
    this.defaultLimit = 6,
    this.minimumSegmentLeads = 15,
    this.minimumResolvedLeads = 10,
    this.minimumStageLeads = 10,
    this.minimumDeliveries = 8,
    this.minimumRateDifference = 0.1,
    this.minimumRelativeDifference = 0.2,
    this.minimumDelayDaysDifference = 3,
    this.staleDays = 14,
    this.severelyStaleDays = 30,
    this.crmHygieneDays = 60,
  })  : assert(defaultLimit > 0),
        assert(minimumSegmentLeads > 0),
        assert(minimumResolvedLeads > 0),
        assert(minimumStageLeads > 0),
        assert(minimumDeliveries > 0);

  final int defaultLimit;
  final int minimumSegmentLeads;
  final int minimumResolvedLeads;
  final int minimumStageLeads;
  final int minimumDeliveries;
  final double minimumRateDifference;
  final double minimumRelativeDifference;
  final double minimumDelayDaysDifference;
  final int staleDays;
  final int severelyStaleDays;
  final int crmHygieneDays;
}
