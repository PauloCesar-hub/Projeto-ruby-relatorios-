
module Utils
  def self.normalize_header(str)
    str.to_s.strip.downcase.gsub(/\s+/, "_")
  end

  def self.symbolize_keys(obj)
    case obj
    when Array then obj.map { |v| symbolize_keys(v) }
    when Hash  then obj.transform_keys { |k| k.to_sym rescue k }.transform_values { |v| symbolize_keys(v) }
    else obj end
  end

  def self.total_amount(rows)
    keys = [:amount, :valor, :price, :preco]
    rows.sum { |r| keys.map { |k| r[k].to_f if r[k] }.compact.first.to_f }
  end
end
