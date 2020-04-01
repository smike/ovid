require "date"
require "time"
require "net/http"
require "json"

class Georgia
  STATE = "Georgia"
  DEPARTMENT = "Georgia Department of Health and Social Services"
  ACRONYM = "GDPH"

  CACHE_KEY = "covid_#{STATE.downcase}"
  CACHE_EXPIRATION_IN_MINUTES = 15

  def self.testing_gallery_url
    nil
  end

  def self.testing_gallery_url
    nil
  end

  def self.testing_feature_url
    "https://services1.arcgis.com/2iUE8l8JKrP2tygQ/arcgis/rest/services/COVID_19_Cases/FeatureServer/0?f=json"
  end

  def self.testing_data_url
    "https://services1.arcgis.com/2iUE8l8JKrP2tygQ/arcgis/rest/services/COVID_19_Cases/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&maxAllowableOffset=&geometryPrecision=&outSR=102100&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=true&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=0&resultRecordCount=50&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pjson&token="
  end

  def self.dashboard_url
    "https://augustagis.maps.arcgis.com/apps/opsdashboard/index.html#/4eec20925b6b4f338368df0ffcba472d"
  end

  def self.covid_tracking_report(query_string)
    stored_response = check_cache(CACHE_KEY)

    if stored_response && !query_string.include?("reload")
      puts "Using stored_response..."
      stored_response
    else
      puts "Generating new report ..."
      get_data
    end
  end

  def self.last_edit
    uri = URI(testing_feature_url)
    response = Net::HTTP.get(uri)
    parsed_response = JSON.parse(response)
    Time.strptime(parsed_response["editingInfo"]["lastEditDate"].to_s, "%Q")
  end

  def self.get_data
    uri = URI(testing_data_url)
    response = Net::HTTP.get(uri)
    parsed_response = JSON.parse(response)

    report = generate_report(parsed_response["features"])

    # set expiration time to 15 minutes from now
    last_fetch = Time.now
    expiration_time = last_fetch + (CACHE_EXPIRATION_IN_MINUTES * 60)

    cache = {
      last_edited_at: last_edit.iso8601,
      last_fetched_at: last_fetch.iso8601,
      expires_at: expiration_time.iso8601,
      data: report
    }

    write_cache(CACHE_KEY, cache)
    set_expiration(CACHE_KEY, expiration_time)
    check_cache(CACHE_KEY)
  end

  def self.generate_report(data)
    # Example data:
    #
    # OBJECTID: 46,
    # NAME: "Worth",
    # GlobalID: "4427d43b-ba56-410d-a125-6b31529954c1",
    # EditDate: 1585678609363,
    # COVID_Cases: 29,
    # COVID_Deaths: 1,
    # COVID_Recovered: null

    totals = relevant_keys.each_with_object({}) do |(key, metric), store|
      store[key] = {
        value: 0,
        name: metric[:name],
        highlight: metric[:highlight],
        source: metric[:source]
      }
    end

    data.each_with_object(totals) do |test, store|
      a = test["attributes"]

      relevant_keys.each do |key, value|
        store[key][:value] += a[value[:source]] || 0
      end
    end
  end

  def self.relevant_keys
    {
      positives: {
        name: "Positives (from Counties)",
        highlight: true,
        source: "COVID_Cases"
      },
      deaths: {
        name: "Deaths (from Counties)",
        highlight: true,
        source: "COVID_Deaths"
      },
      recovered: {
        name: "Recovered (from Counties)",
        highlight: true,
        source: "COVID_Recovered"
      }
    }
  end

  def self.production?
    ENV["RACK_ENV"] == "production"
  end

  def self.development?
    !production?
  end

  def self.cache
    @redis ||= if production?
      Redis.new(url: ENV["REDIS_URL"])
    else
      Redis.new
    end
  end

  def self.check_cache(key)
    payload = cache.get(key)

    if payload
      puts "cache hit for #{key}"
      JSON.parse(payload, { symbolize_names: true })
    else
      puts "cache miss for #{key}"
    end
  end

  def self.write_cache(key, value)
    puts "cache write for #{key}"
    payload = value.to_json
    puts "caching serialized payload: #{payload.inspect}"

    cache.multi do
      cache.set(key, payload)
      cache.get(key)
    end
  end

  def self.set_expiration(key, time)
    cache.expireat(key, time.to_i)
  end
end
