require 'rails_helper'

RSpec.describe Reports::AgentActivityCalculator do
  describe '.active_hours' do
    it 'returns 0.0 for empty timestamps' do
      expect(described_class.active_hours([])).to eq(0.0)
    end

    it 'returns 0.1 for a single timestamp' do
      expect(described_class.active_hours([Time.zone.now])).to eq(0.1)
    end

    it 'excludes offline break time and sums continuous work periods' do
      # Morning: 09:00, 09:05, 09:10 (10 mins + 3 min pad = 13 mins = 0.2h)
      morning = (0..2).map { |i| Time.zone.parse('2026-09-14 09:00:00') + (i * 5).minutes }
      # 3 hour break
      # Afternoon: 13:00, 13:05, 13:10 (10 mins + 3 min pad = 13 mins = 0.2h)
      afternoon = (0..2).map { |i| Time.zone.parse('2026-09-14 13:00:00') + (i * 5).minutes }

      hours = described_class.active_hours(morning + afternoon)
      expect(hours).to eq(0.4)
    end
  end

  describe '.rate' do
    it 'returns rate when hours are positive' do
      expect(described_class.rate(10, 2.0)).to eq(5.0)
    end

    it 'returns nil when hours are zero or empty' do
      expect(described_class.rate(10, 0.0)).to be_nil
    end
  end
end
