<script setup>
import ReportHeader from './components/ReportHeader.vue';
import ConversationHeatmapContainer from './components/heatmaps/ConversationHeatmapContainer.vue';
import ResolutionHeatmapContainer from './components/heatmaps/ResolutionHeatmapContainer.vue';
import AgentLiveReportContainer from './components/AgentLiveReportContainer.vue';
import TeamLiveReportContainer from './components/TeamLiveReportContainer.vue';
import StatsLiveReportsContainer from './components/StatsLiveReportsContainer.vue';
import ChannelDistributionContainer from './components/ChannelDistributionContainer.vue';
</script>

<template>
  <ReportHeader :header-title="$t('OVERVIEW_REPORTS.HEADER')" />
  <div class="flex flex-col gap-4 pb-6">
    <StatsLiveReportsContainer />
    <ChannelDistributionContainer />
    <ConversationHeatmapContainer />
    <ResolutionHeatmapContainer />
    <AgentLiveReportContainer />
    <TeamLiveReportContainer />
  </div>
</template>
