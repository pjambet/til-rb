#!/usr/bin/env ruby

require 'readline'
require 'base64'
# p ARGV

require 'octokit'

client = Octokit::Client.new(access_token: ENV["GH_TOKEN"])
#user = client.user 'pjambet'
#puts user.name
# repo = client.repo 'pjambet/til'
# p repo

# ref = client.ref "pjambet/til", "heads/master"

cats = client.contents('pjambet/til', path: '').filter { |c| c["type"] == "dir" }
# p cats

# p client.contents('pjambet/til', path: 'git/')

# sleep 5

# require 'stringio'
title = ARGV[1]
r, w = IO.pipe
r2, w2 = IO.pipe
# pid = Process.spawn("echo \"foo\\nbar\\nbaz\\nqux\" | fzf", {in: reader, out: writer})
pid = Process.spawn("fzf", {out: w, in: r2})
r2.close
w2.puts (cats.map { |c| c[:name] } << "something else").join("\n")
w2.close
w.close
# reader.close
# writer.puts "foo\nbar\nbaz"
Process.waitpid(pid)
# p 'done waiting'
sel = r.gets.chomp
new_cat = false
r.close
if sel == "something else"
  new_cat = true
  puts "What do you want it to be called? "
  sel = Readline.readline("> ")
end

File.open("something.md", "w") { |f|
  f.write("# " + (title || "Title Placeholder"))
  f.write("\n"*2)
  f.write("What did you learn about #{sel} today")
}
# p ENV['VISUAL']
# p ENV['EDITOR']
editor = ENV['VISUAL'] || ENV['EDITOR'] || "vi"
system(*editor.split, "something.md")
content = File.read("something.md")
File.unlink("something.md")

# p "You chose #{ sel }"
# p content
cat = sel

ref = client.ref "pjambet/til", "heads/master"
commit = client.commit "pjambet/til", ref.object.sha
tree = client.tree "pjambet/til", commit.commit.tree.sha, recursive: true
readme = client.readme "pjambet/til"
readme_content = Base64.decode64 readme.content

# Create blob for new file
blob = client.create_blob "pjambet/til", content
blobs = tree.tree.filter { |h|
  h[:type] == "blob" && h[:path] != "README.md"
}.map { |r|
  r.to_h.slice(:path, :mode, :type, :sha)
}

commit_title = content.lines[0].chomp
if commit_title.start_with?("#")
  commit_title = commit_title[1..-1].strip
end

today = Time.now.strftime "%Y-%m-%d"
name = commit_title.split.map(&:downcase).join('-')
filename = "#{today}_#{name}.md"

blobs << { path: "#{cat}/#{filename}", mode: "100644", type: "blob", sha: blob }

# Update README
beginning = readme_content.index("### Categories") + "### Categories".length
eend = readme_content.index('---', readme_content.index('---') + 1) - 1
# [["[Git](#git)", "Git", "git"], ["[Qux](#qux)", "Qux", "qux"]]
categories = readme_content[beginning..eend].scan(/(\[(\w+)\]\(#(\w+)\))/)

if new_cat
else
  existing_cat = categories.find { |c| c[2] == cat }
  loc_in_page = readme_content.index("### #{existing_cat[1]}")
  next_cat_location = readme_content.index("###", loc_in_page + 1)

  new_line = "- [#{commit_title}](#{cat}/#{filename})"
  new_readme_content = ""
  if next_cat_location
    new_readme_content = readme_content[0..(next_cat_location - 2)] + new_line + readme_content[(next_cat_location - 2)..-1]
  else
    new_readme_content = readme_content + new_line + "\n"
  end
end

# Create blob for new revision of README
new_readme_blob = client.create_blob "pjambet/til", new_readme_content
blobs << { path: "README.md", mode: "100644", type: "blob", sha: new_readme_blob }

tree = client.create_tree "pjambet/til", blobs
commit = client.create_commit "pjambet/til", commit_title, tree.sha, ref.object.sha
# p commit
client.update_ref "pjambet/til", "heads/master", commit.sha
