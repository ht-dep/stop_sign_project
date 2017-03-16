class RunPredictor

  def can_be_learned(method)
    return Vote.where(vote_method: method).count > 300 && Vote.where(vote_method: method, vote: 0).distinct(:stop_id).count > 100 && Vote.where(vote_method: method, vote: 1).distinct(:stop_id).count > 100
  end

  #eventually this needs memory optimization.
  def export_datasheet(method, time)
    csv = CSV.open("#{CONFIG["project_dir"]}datasheet_#{method}_#{time.to_i}.csv", "w")
    vote_avgs = []
    StopSignLog.each do |ssl|
    vote_avg = Vote.where(stop_id: ssl.stop_id, vote_method: method).to_a.collect(&:vote).average
      if Vote.where(stop_id: ssl.stop_id, vote_method: method).count >= 1
        if vote_avg > 0.5
          vote_avg = 1
        else
          vote_avg = 0
        end
        row = [vote_avg]
        vote_avgs << vote_avg
        ssl.ml_row.collect{|x| row << x}
        csv << row
      end
    end
    csv.close
    return "datasheet_#{method}_#{time.to_i}.csv"
  end
  
  def run
    time = Time.now
    ["presence", "stop_violations", "wrong_way_violations"].each do |method|
      if can_be_learned(method)
        filename = export_datasheet(method, time)
        ml = MachineLearner.first_or_create(vote_method: method)
        acc = ml.accuracy.to_f
        results = `python #{CONFIG["project_dir"]}/predictor.py --file #{CONFIG["project_dir"]}datasheet_#{method}_#{time.to_i}.csv --prev_acc #{acc} --method #{method}`
        accuracy = results.strip
        ml.accuracy = (accuracy.to_f.round(4)*100)
        ml.save!
      end
    end
  end
end