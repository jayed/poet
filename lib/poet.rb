require "poet/version"
require "thor"
require "fileutils"

class PoetCLI < Thor

  MAGIC_LINE = "# Generated by #{File.basename(__FILE__, '.rb')}"

  default_task :create
  class_option :dir,
      desc: 'Use specified directory to collect conf files',
      default: ENV['POET_GLOBDIR'] || File.expand_path('~/.ssh/config.d')
  class_option :output,
      desc: 'Generate output in specified file',
      aliases: '-o',
      default: ENV['POET_OUTPUT'] || File.expand_path('~/.ssh/config')
  class_option :with,
      desc: 'Include an otherwise disabled config file',
      aliases: '-w',
      default: ""
  class_option :verbose,
      desc: 'Be verbose',
      aliases: '-v',
      type: :boolean

  desc "bootstrap [FILE]",
      "Move ~/.ssh/config (or whatever you specified) to ~/.ssh/config.d/ to help you get started"
  def bootstrap(file=nil)
    file ||= File.expand_path(file || options[:output])
    if File.directory?(options[:dir])
      $stderr.puts "You're already good to go."
      Process.exit!(3)
    end
    FileUtils.mkdir_p(options[:dir])
    FileUtils.mv(file, options[:dir])
    create
  end

  desc "", "Concatenate all host stanzas under ~/.ssh/config.d/ into a single ~/.ssh/config"
  def create
    if !File.directory?(options[:dir])
      $stderr.puts "#{options[:dir]} does not exist or is not a directory"
      Process.exit!(1)
    end

    if File.exists?(options[:output]) && File.new(options[:output]).gets == "#{MAGIC_LINE}\n"
      puts "Found generated ssh_config under #{options[:output]}. Overwriting..."
    elsif File.exists?(options[:output])
      $stderr.puts "Found hand-crafted ssh_config under #{options[:output]}. Please move it out of the way or specify a different output file with the -o option."
      Process.exit!(2)
    end

    whitelist = options[:with].split(',')
    files = Dir["#{options[:dir]}/**/*"].reject do |file|
      File.directory?(file) || \
        file =~ /\.disabled$/ && !whitelist.include?("#{File.basename(file, '.disabled')}")
    end

    files -= [options[:output]]

    entries = []

    files.sort.each do |file|
      entries << File.read(file)
      $stdout.puts "Using #{file.gsub(/^\.\//, '')}" if options[:verbose]
    end

    File.open(options[:output], 'w', 0600) do |ssh_config|
      ssh_config.puts(MAGIC_LINE)
      ssh_config.puts("# DO NOT EDIT THIS FILE")
      ssh_config.puts("# Create or modify files under #{options[:dir]} instead")
      ssh_config.puts(entries.join("\n"))
    end
  end

  desc "edit FILE", "Open FILE under ~/.ssh/config.d/ in your favorite $EDITOR"
  def edit(file)
    if ENV['EDITOR'].to_s.empty?
      $stderr.puts "$EDITOR is empty. Could not determine your favorite editor."
      Process.exit!(4)
    end
    system("#{ENV['EDITOR']} #{File.join(options[:dir], file)}")
    create
  end

end