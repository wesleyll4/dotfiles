#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
task_file="$root/ansible/roles/omarchy_storage_tuning/tasks/main.yml"

ruby -ryaml - "$task_file" <<'RUBY'
tasks = YAML.load_file(ARGV.fetch(0))
task = tasks.find { |candidate| candidate["name"] == "Add approved dm-crypt options to native Limine cmdline" }
expected = "omarchy_storage_tuning_current_state == 'original'"
assignment_index = tasks.index { |candidate| candidate["name"] == "Extract active default Limine cmdline assignments" }
assignment_assert_index = tasks.index { |candidate| candidate["name"] == "Require exactly one active default Limine cmdline assignment" }
complete_index = tasks.index { |candidate| candidate["name"] == "Extract complete active default Limine cmdline" }
regexp = task && task.dig("ansible.builtin.replace", "regexp")

unless task && task["when"] == expected
  warn "RED: Limine replace task must run only for the original cryptdevice state"
  exit 1
end

unless regexp&.include?("[^\"'\\n\\r]")
  warn "RED: Limine replace regexp must exclude newline and carriage return"
  exit 1
end

unless assignment_index && assignment_assert_index && complete_index && assignment_index < assignment_assert_index && assignment_assert_index < complete_index
  warn "RED: active default assignments must be counted before complete cmdline parsing"
  exit 1
end

puts "Omarchy storage tuning task structure: ok"
RUBY
