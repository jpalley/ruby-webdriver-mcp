FROM ruby:3.2

WORKDIR /workspace

# Install dependencies
COPY Gemfile selenium-webdriver-mcp.gemspec ./
COPY lib/selenium_webdriver_mcp/version.rb ./lib/selenium_webdriver_mcp/

RUN bundle install

# Copy the rest of the application
COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "selenium-mcp-server"]
