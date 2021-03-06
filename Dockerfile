FROM ubuntu:20.04

ENV DEBIAN_FRONTEND nointeractive
ENV TZ Asia/Tokyo
ENV PATH $PATH:/root/.rbenv/shims:/root/.rbenv/bin

WORKDIR /project/tms2.0_api

VOLUME [ "/project/tms2.0_api/db" ]

EXPOSE 4567

RUN apt update
RUN apt upgrade -y
RUN apt install -y ca-certificates git gcc make perl autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev tzdata screen aptitude libsqlite3-dev curl wget ruby-dev
RUN aptitude install -y ruby-rmagick libmagickcore-6-headers libmagickcore-dev libmagickwand-dev
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv
RUN echo 'eval "$(rbenv init -)"' >> ~/.bashrc
RUN ~/.rbenv/bin/rbenv init; exit 0
RUN git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
RUN rbenv install 2.7.1
RUN rbenv local 2.7.1

COPY ./ /project/tms2.0_api

RUN rbenv exec gem install bundler rake
RUN rbenv exec bundle install
RUN rbenv exec rake db:migrate

CMD [ "rbenv", "exec", "ruby", "app.rb", "-o", "0.0.0.0"]