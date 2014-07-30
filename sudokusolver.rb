class Sudoku
  
  def initialize(filename, size=9)
    @size = size
    @box_size = size / 3
    @table = create_table(filename)
  end
  
  def print_table
    (0...@size).each do |x|
      row = (0...@size).each.map { |y| @table[[x, y]][0].to_s }
      puts row.join(" ")
    end
  end
  
  def play
    do_singles && do_hidden_singles
  end
  
  private
  
    def create_table(filename)
      table = Hash.new
      (0...@size).each do |x|
        (0...@size).each do |y|
          table[[x, y]] = (1..@size).to_a
        end
      end
      File.open(filename).each_line do |line|
        digits = /\((\d), (\d)\): (\d)/.match(line)
        this_x, this_y = digits[1].to_i, digits[2].to_i
        table[[this_x, this_y]] = [digits[3].to_i]
      end
      return table
    end
  
    def do_singles
      no_change_made = true
      (0...@size).each do |x|
        (0...@size).each do |y|
          curr_cell = @table[[x, y]]
          next if curr_cell.include? :done
          if curr_cell.size == 1
            curr_cell_value = curr_cell[0]
            (0...@size).each { |y_cursor| @table[[x, y_cursor]].delete(curr_cell_value) unless y_cursor == y }
            (0...@size).each { |x_cursor| @table[[x_cursor, y]].delete(curr_cell_value) unless x_cursor == x }
            box_x_start = (x / @box_size) * @box_size
            box_y_start = (y / @box_size) * @box_size
            (box_x_start...(box_x_start + @box_size)).each do |box_x|
              (box_y_start...(box_y_start + @box_size)).each do |box_y|
                next if [box_x, box_y] == [x, y]
                @table[[box_x, box_y]].delete(curr_cell_value)
              end
            end
            no_change_made = false
            curr_cell.push(:done)
          end
        end
      end
      no_change_made
    end

    def do_hidden_singles
      no_change_made = true
      (0..2).each do |m|
        (0..2).each do |n|
          all_numbers_in_box = Hash.new
          (1..@size).each { |i| all_numbers_in_box[i] = [] }
          ((m * @box_size)...((m * @box_size) + @box_size)).each do |box_x|
            ((n * @box_size)...((n * @box_size) + @box_size)).each do |box_y|
              @table[[box_x, box_y]].each { |num| all_numbers_in_box[num].push([box_x, box_y]) unless num == :done }
            end
          end
          all_numbers_in_box.each do |num, cells|
            x_vals = cells.map { |cell| cell[0] }
            y_vals = cells.map { |cell| cell[1] }
            if cells.size == 1
              @table[cells[0]] = [num] unless @table[cells[0]].include?(:done)
            else
              if x_vals.uniq.size == 1
                (0...@size).each { |y_cursor| @table[[x_vals[0], y_cursor]].delete(num) unless y_vals.include?(y_cursor) }
                no_change_made = false
              end
              if y_vals.uniq.size == 1
                (0...@size).each { |x_cursor| @table[[x_cursor, y_vals[0]]].delete(num) unless x_vals.include?(x_cursor) }
                no_change_made = false
              end
            end
          end
        end
      end
      no_change_made
    end
  
end

sudoku = Sudoku.new(ARGV[0])

loop do
  break if sudoku.play
end

sudoku.print_table