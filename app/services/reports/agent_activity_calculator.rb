# Calculates active work time from real event timestamps without counting offline/break gaps.
# Groups timestamps within a 15-minute inactivity threshold into continuous sessions.
class Reports::AgentActivityCalculator
  SESSION_GAP = 15.minutes.to_i
  ACTION_PAD = 3.minutes.to_i

  def self.active_hours(timestamps)
    return 0.0 if timestamps.empty?

    sorted = timestamps.map(&:to_i).sort.uniq
    return 0.1 if sorted.size == 1

    total_seconds = 0
    prev = sorted.first

    sorted[1..].each do |t|
      gap = t - prev
      total_seconds += (gap <= SESSION_GAP ? gap : ACTION_PAD)
      prev = t
    end
    total_seconds += ACTION_PAD

    (total_seconds.to_f / 1.hour).round(1)
  end

  def self.rate(count, hours)
    hours.positive? ? (count.to_f / hours).round(1) : nil
  end
end
