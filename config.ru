require 'rubygems'
require 'bundler'

Bundler.require

require "./states/state"
require "./states/florida"
require "./states/utah"
require "./states/washington"
require "./states/alaska"
require "./states/georgia"
require "./states/texas"
require "./states/california"
require "./states/louisiana"
require "./states/new_jersey"

if State.development?
  require 'dotenv'
  Dotenv.load
else
  Bugsnag.configure do |config|
    config.api_key = ENV["BUGSNAG_API_KEY"]
  end

  use Bugsnag::Rack
end

app = Hanami::Router.new do
  get "/", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], nil))
    ]
  }
  get "/florida", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], Florida))
    ]
  }
  get "/utah", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], Utah))
    ]
  }
  get "/washington", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], Washington))
    ]
  }
  get "/alaska", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], Alaska))
    ]
  }
  get "/georgia", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], Georgia))
    ]
  }
  get "/texas", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], Texas))
    ]
  }
  get "/california", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], California))
    ]
  }
  get "/louisiana", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], Louisiana))
    ]
  }
  get "/new-jersey", to: ->(env) {
    [
      200, {"Content-Type" => "text/html"},
      StringIO.new(App.payload(env["QUERY_STRING"], NewJersey))
    ]
  }
end

run app

class App
  def self.pretty_datetime(time)
    format = "%A %B %e, %Y at %H:%M:%S %Z".freeze

    if time.respond_to? :strftime
      time.strftime(format)
    else
      Time.parse(time).strftime(format)
    end
  end

  def self.payload(query_string, class_name)
    <<~HTML
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>#{class_name ? class_name.state_name + " " : nil}Ovid COVID-19 report</title>
      <style type="text/css">
        #{css}
      </style>
    </head>
    <body>
      <nav>
        <ul>
          <li><a href="/">Home</a></li>
          <li><a href="/alaska">Alaska</a></li>
          <li><a href="/california">California</a></li>
          <li><a href="/florida">Florida</a></li>
          <li><a href="/georgia">Georgia</a></li>
          <li><a href="/louisiana">Louisiana</a></li>
          <li><a href="/new-jersey">New Jersey</a></li>
          <li><a href="/texas">Texas</a></li>
          <li><a href="/utah">Utah</a></li>
          <li><a href="/washington">Washington</a></li>
        </ul>
      </nav>

      #{class_name ? state_page(class_name, query_string) : home_page}

      <hr />
      <p>
        <a href="https://github.com/olivierlacan/ovid/">Source code for this website</a>
         - Maintained by <a href="https://olivierlacan.com">Olivier Lacan</a> for <a href="https://covidtracking.com/">The COVID Tracking Project</a>
      </p>
    </body>
    </html>
    HTML
  end

  def self.home_page
    <<~HTML
      <h1>Ovid</h1>
      <p>
        This project aggregates county-level data from U.S. states for
        which ArcGIS public Feature Layers (datasets) are available.
      </p>

      <p>
        While this data may not always be authoritative, it allows for
        COVID-19 case and testing information released by states in
        other avenues to be compared with raw data emanating from their
        own counties.
      </p>

      <p>
        Please corroborate this data prior to use in any journalistic or
        data scientific endeavor. State pages link to ArcGIS dashboards
        whenever possible and the source feature layers are listed to
        help independent
        verification.
      </p>
    HTML
  end

  def self.state_page(class_name, query_string)
    report = class_name.covid_tracking_report(query_string)

    last_edit = pretty_datetime report[:last_edited_at]
    last_fetched = pretty_datetime report[:last_fetched_at]
    expires_at = pretty_datetime report[:expires_at]

    <<~HTML
      <h1>#{class_name.state_name} COVID-19 Report</h1>
      <p>
        This report is generated from the #{class_name::DEPARTMENT}'s COVID-19
        <a href="#{class_name&.testing_gallery_url || class_name.testing_feature_url}">
        ArcGIS feature layer</a>.
        <br />
        #{class_name::ACRONYM} maintains a <a href="#{class_name.dashboard_url}">dashboard</a> representation of this
        data which is created from the same source.
      </p>

      #{report_table(report[:data])}

      <p><code>*</code> denotes metrics tracked by the COVID Tracking Project</p>

      <footer>
        <p>
          Data last generated by #{class_name::ACRONYM} at <strong>#{last_edit}</strong>.<br />
          Last fetched from API at <strong>#{last_fetched}</strong>.<br />
          This data will remain cached until <strong>#{expires_at}</strong> so you don't need to
          refresh this page until then to get new data.
        </p>

        <a href="?reload">Force reload</a>

        #{class_name.nomenclature if defined?(class_name.nomenclature)}
      </footer>
    HTML
  end

  def self.report_table(data)
    rows = data.map do |_key, metric|
      <<~HTML
        <tr>
          <td title="#{metric[:source]}">#{metric[:name]}#{"*" if metric[:highlight]}</td>
          <td>#{metric[:value]}</td>
          <td>#{metric[:description]}</td>
        </tr>
      HTML
    end.join("\n")

    output = <<~HTML
      <table>
        <tr>
          <th>Metric</th>
          <th>Value</th>
          <th>Description</th>
        </tr>
        #{rows}
      </table>
    HTML
  end

  def self.css
    <<~HTML
      body {
        font-family: Tahoma, sans-serif;
      }

      nav ul {
        padding: 0;
      }
      nav li {
        list-style: none;
        display: inline-block;
      }

      table {
        width: 100%
      }
      th, td {
        padding: 0.3rem 1rem;
      }

      th {
        position: sticky;
        top: 15px;
        background: white;
      }

      td:first-child, th:first-child {
        text-align: right;
        width: 25%;
      }

      td:nth-child(2), th:nth-child(2) {
        text-align: right;
        width: 5%;
      }

      td:last-child, th:last-child {
        text-align: left;
        width: 70%;
      }

      tr:nth-child(even) { background: #CCC }
      tr:nth-child(odd) { background: #FFF }
    HTML
  end
end
