#Starts the program by calling initialize in FoodDB.rb
#require_relative 'FoodDB'
#require_relative 'Log'

#Main controller for the program. Reads in user input
#from the command line and takes appropriate action
$stdin.each do |line|
  puts ' '
  words = line.strip!.split(' ')
  first = words[0]
  words.delete_at(0)
  last = words.inject(''){|name, word| name << ' ' << word }
  last.strip!

  case first
  when 'quit'
    break
  when 'save'
    
  when 'new'
    food.create_food(last)
  when 'print'
    
  when 'find'
    
  when 'log'
    
  when 'show'
    if last.length < 1
      log.show
    elsif last.eql? 'all'
      log.show_all
    else
      log.show(last)
    end
  when 'delete'
    log.delete(last)
  else
    puts 'Enter a valid command'
  end
  puts ' '
end
log.save
food.save
