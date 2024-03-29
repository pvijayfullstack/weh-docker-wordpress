# -*- encoding: utf-8 -*-
# stub: disposable 0.4.2 ruby lib

Gem::Specification.new do |s|
  s.name = "disposable".freeze
  s.version = "0.4.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Nick Sutterer".freeze]
  s.date = "2017-01-31"
  s.description = "Decorators on top of your ORM layer.".freeze
  s.email = ["apotonick@gmail.com".freeze]
  s.homepage = "https://github.com/apotonick/disposable".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.6.11".freeze
  s.summary = "Decorators on top of your ORM layer with change tracking, collection semantics and nesting.".freeze

  s.installed_by_version = "2.6.11" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<uber>.freeze, ["< 0.2.0"])
      s.add_runtime_dependency(%q<declarative>.freeze, ["< 1.0.0", ">= 0.0.9"])
      s.add_runtime_dependency(%q<declarative-builder>.freeze, ["< 0.2.0"])
      s.add_runtime_dependency(%q<declarative-option>.freeze, ["< 0.2.0"])
      s.add_runtime_dependency(%q<representable>.freeze, ["<= 3.1.0", ">= 2.4.0"])
      s.add_development_dependency(%q<bundler>.freeze, ["~> 1.3"])
      s.add_development_dependency(%q<rake>.freeze, [">= 0"])
      s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
      s.add_development_dependency(%q<activerecord>.freeze, ["= 4.2.5"])
      s.add_development_dependency(%q<sqlite3>.freeze, [">= 0"])
      s.add_development_dependency(%q<dry-types>.freeze, ["~> 0.6"])
    else
      s.add_dependency(%q<uber>.freeze, ["< 0.2.0"])
      s.add_dependency(%q<declarative>.freeze, ["< 1.0.0", ">= 0.0.9"])
      s.add_dependency(%q<declarative-builder>.freeze, ["< 0.2.0"])
      s.add_dependency(%q<declarative-option>.freeze, ["< 0.2.0"])
      s.add_dependency(%q<representable>.freeze, ["<= 3.1.0", ">= 2.4.0"])
      s.add_dependency(%q<bundler>.freeze, ["~> 1.3"])
      s.add_dependency(%q<rake>.freeze, [">= 0"])
      s.add_dependency(%q<minitest>.freeze, [">= 0"])
      s.add_dependency(%q<activerecord>.freeze, ["= 4.2.5"])
      s.add_dependency(%q<sqlite3>.freeze, [">= 0"])
      s.add_dependency(%q<dry-types>.freeze, ["~> 0.6"])
    end
  else
    s.add_dependency(%q<uber>.freeze, ["< 0.2.0"])
    s.add_dependency(%q<declarative>.freeze, ["< 1.0.0", ">= 0.0.9"])
    s.add_dependency(%q<declarative-builder>.freeze, ["< 0.2.0"])
    s.add_dependency(%q<declarative-option>.freeze, ["< 0.2.0"])
    s.add_dependency(%q<representable>.freeze, ["<= 3.1.0", ">= 2.4.0"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.3"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<minitest>.freeze, [">= 0"])
    s.add_dependency(%q<activerecord>.freeze, ["= 4.2.5"])
    s.add_dependency(%q<sqlite3>.freeze, [">= 0"])
    s.add_dependency(%q<dry-types>.freeze, ["~> 0.6"])
  end
end
