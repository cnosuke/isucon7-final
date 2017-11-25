require 'concurrent-edge'
require 'faye/websocket'
require 'json'
require 'mysql2'

class Game
  module Jsonable
    def to_json(*args)
      JSON.dump(as_json)
    end

    def as_json
      to_h
    end
  end

  GameRequest = Struct.new(:request_id, :action, :time, :isu, :item_id, :count_bought)

  class GameResponse < Struct.new(:request_id, :is_success)
    include Jsonable
  end

  class Exponential < Struct.new(:mantissa, :exponent)
    include Jsonable

    def as_json
      [mantissa, exponent]
    end
  end

  class Adding < Struct.new(:room_name, :time, :isu)
    include Jsonable

    def as_json
      super.merge(isu: isu.to_s)
    end
  end

  class Buying < Struct.new(:room_name, :item_id, :ordinal, :time)
    include Jsonable
  end

  class Schedule < Struct.new(:time, :milli_isu, :total_power)
    include Jsonable
  end

  class Item < Struct.new(:item_id, :count_bought, :count_built, :next_price, :power, :building)
    include Jsonable

    def as_json
      super.merge(count_bought: count_bought.to_i, count_built: count_built.to_i)
    end
  end

  class OnSale < Struct.new(:item_id, :time)
    include Jsonable
  end

  class Building < Struct.new(:time, :count_built, :power)
    include Jsonable
  end

  class GameStatus < Struct.new(:time, :adding, :schedule, :items, :on_sale)
    include Jsonable
  end

  class MItem
    attr_reader :item_id, :power1, :power2, :power3, :power3, :power4, :price1, :price2, :price3, :price4

    def initialize(item_id:, power1:, power2:, power3:, power4:, price1:, price2:, price3:, price4:)
      @item_id = item_id
      @power1 = power1
      @power2 = power2
      @power3 = power3
      @power4 = power4
      @price1 = price1
      @price2 = price2
      @price3 = price3
      @price4 = price4
    end

    def get_power(count)
      # power(x):=(p3*x + 1) * p4 ** (p1*x + p2)
      s = @power3 * count + 1
      t = @power4 ** (@power1 * count + @power2)
      s * t
    end

    def get_price(count)
      # price(x):=(p3*x + 1) * p4 ** (p1*x + p2)
      s = @price3 * count + 1
      t = @price4 ** (@price1 * count + @price2)
      s * t
    end
  end

  # +---------+--------+--------+--------+--------+--------+--------+--------+--------+
  # | item_id | power1 | power2 | power3 | power4 | price1 | price2 | price3 | price4 |
  # +---------+--------+--------+--------+--------+--------+--------+--------+--------+
  # |       1 |      0 |      1 |      0 |      1 |      0 |      1 |      1 |      1 |
  # |       2 |      0 |      1 |      1 |      1 |      0 |      1 |      2 |      1 |
  # |       3 |      1 |     10 |      0 |      2 |      1 |      3 |      1 |      2 |
  # |       4 |      1 |     24 |      1 |      2 |      1 |     10 |      0 |      3 |
  # |       5 |      1 |     25 |    100 |      3 |      2 |     20 |     20 |      2 |
  # |       6 |      1 |     30 |    147 |     13 |      1 |     22 |     69 |     17 |
  # |       7 |      5 |     80 |    128 |      6 |      6 |     61 |    200 |      5 |
  # |       8 |     20 |    340 |    180 |      3 |      9 |    105 |    134 |     14 |
  # |       9 |     55 |    520 |    335 |      5 |     48 |    243 |    600 |      7 |
  # |      10 |    157 |   1071 |   1700 |     12 |    157 |    625 |   1000 |     13 |
  # |      11 |   2000 |   7500 |   2600 |      3 |   2001 |   5430 |   1000 |      3 |
  # |      12 |   1000 |   9000 |      0 |     17 |    963 |   7689 |      1 |     19 |
  # |      13 |  11000 |  11000 |  11000 |     23 |  10000 |      2 |      2 |     29 |
  # +---------+--------+--------+--------+--------+--------+--------+--------+--------+
  MITEM_BY_ID = {
     1 => MItem.new(item_id:  1, power1:      0, power2:     1, power3:     0, power4:     1, price1:     0, price2:     1, price3:     1, price4:     1),
     2 => MItem.new(item_id:  2, power1:      0, power2:     1, power3:     1, power4:     1, price1:     0, price2:     1, price3:     2, price4:     1),
     3 => MItem.new(item_id:  3, power1:      1, power2:    10, power3:     0, power4:     2, price1:     1, price2:     3, price3:     1, price4:     2),
     4 => MItem.new(item_id:  4, power1:      1, power2:    24, power3:     1, power4:     2, price1:     1, price2:    10, price3:     0, price4:     3),
     5 => MItem.new(item_id:  5, power1:      1, power2:    25, power3:   100, power4:     3, price1:     2, price2:    20, price3:    20, price4:     2),
     6 => MItem.new(item_id:  6, power1:      1, power2:    30, power3:   147, power4:    13, price1:     1, price2:    22, price3:    69, price4:    17),
     7 => MItem.new(item_id:  7, power1:      5, power2:    80, power3:   128, power4:     6, price1:     6, price2:    61, price3:   200, price4:     5),
     8 => MItem.new(item_id:  8, power1:     20, power2:   340, power3:   180, power4:     3, price1:     9, price2:   105, price3:   134, price4:    14),
     9 => MItem.new(item_id:  9, power1:     55, power2:   520, power3:   335, power4:     5, price1:    48, price2:   243, price3:   600, price4:     7),
    10 => MItem.new(item_id: 10, power1:    157, power2:  1071, power3:  1700, power4:    12, price1:   157, price2:   625, price3:  1000, price4:    13),
    11 => MItem.new(item_id: 11, power1:   2000, power2:  7500, power3:  2600, power4:     3, price1:  2001, price2:  5430, price3:  1000, price4:     3),
    12 => MItem.new(item_id: 12, power1:   1000, power2:  9000, power3:     0, power4:    17, price1:   963, price2:  7689, price3:     1, price4:    19),
    13 => MItem.new(item_id: 13, power1:  11000, power2: 11000, power3: 11000, power4:    23, price1: 10000, price2:     2, price3:     2, price4:    29),
  }.freeze

  class << self
    def initialize!
      conn = connect_db
      begin
        conn.query('TRUNCATE TABLE adding')
        conn.query('TRUNCATE TABLE buying')
        conn.query('TRUNCATE TABLE room_time')
      rescue => e
        puts e.message
      else
        conn.close
      end
    end

    def str2big(s)
      s.to_i
    end

    def big2exp(n)
      s = n.to_s

      if s.length <= 15
        return Exponential.new(n, 0)
      end

      t = s[0,15].to_i
      Exponential.new(t, (s.length - 15))
    end

    def get_current_time(conn)
      conn.query('SELECT floor(unix_timestamp(current_timestamp(3))*1000) AS value').first['value']
    end

    # 部屋のロックを取りタイムスタンプを更新する
    #
    # トランザクション開始後この関数を呼ぶ前にクエリを投げると、
    # そのトランザクション中の通常のSELECTクエリが返す結果がロック取得前の
    # 状態になることに注意 (keyword: MVCC, repeatable read).
    def update_room_time(conn, room_name, req_time)
      # See page 13 and 17 in https://www.slideshare.net/ichirin2501/insert-51938787
      statement = conn.prepare('INSERT INTO room_time(room_name, time) VALUES (?, 0) ON DUPLICATE KEY UPDATE time = time')
      statement.execute(room_name)
      statement.close

      statement = conn.prepare('SELECT time FROM room_time WHERE room_name = ? FOR UPDATE')
      room_time = statement.execute(room_name).first['time']
      statement.close

      current_time = get_current_time(conn)

      if room_time > current_time
        raise ArgumentError.new, 'room time is future'
      end

      if !req_time.zero? && req_time < current_time
        raise ArgumentError.new, 'reqTime is past'
      end

      statement = conn.prepare('UPDATE room_time SET time = ? WHERE room_name = ?')
      statement.execute(current_time, room_name)
      statement.close

      current_time
    end

    def add_isu(room_name, req_isu, req_time)
      conn = connect_db

      begin
        conn.query('BEGIN')

        update_room_time(conn, room_name, req_time)

        statement = conn.prepare('INSERT INTO adding(room_name, time, isu) VALUES (?, ?, "0") ON DUPLICATE KEY UPDATE isu=isu')
        statement.execute(room_name, req_time)
        statement.close

        statement = conn.prepare('SELECT isu FROM adding WHERE room_name = ? AND time = ? FOR UPDATE')
        isu_str = statement.execute(room_name, req_time).first['isu']
        statement.close
        isu = str2big(isu_str)

        isu += req_isu
        statement = conn.prepare('UPDATE adding SET isu = ? WHERE room_name = ? AND time = ?')
        statement.execute(isu.to_s, room_name, req_time)
        statement.close
      rescue => e
        puts "fail to add isu: room=#{room_name} time=#{req_time} isu=#{req_isu}"
        conn.query('ROLLBACK')
        conn.close
        false
      else
        conn.query('COMMIT')
        conn.close
        true
      end
    end

    def buy_item(room_name, item_id, count_bought, req_time)
      conn = connect_db

      begin
        conn.query('BEGIN')

        update_room_time(conn, room_name, req_time)

        statement = conn.prepare('SELECT COUNT(*) AS count FROM buying WHERE room_name = ? AND item_id = ?')
        count_buying = statement.execute(room_name, item_id).first['count']
        statement.close

        if count_buying != count_bought
          conn.query('ROLLBACK')
          puts "#{room_name}, #{item_id}, #{count_bought + 1} is already bought"
          return false
        end

        total_milli_isu = 0
        statement = conn.prepare('SELECT isu FROM adding WHERE room_name = ? AND time <= ?')
        addings = statement.execute(room_name, req_time).map do |raw_adding|
          Adding.new(room_name, req_time, raw_adding['isu'])
        end
        statement.close

        addings.each do |a|
          total_milli_isu += str2big(a.isu) * 1000
        end

        statement = conn.prepare('SELECT item_id, ordinal, time FROM buying WHERE room_name = ?')
        buyings = statement.execute(room_name).map do |raw_buying|
          Buying.new(room_name, raw_buying['item_id'], raw_buying['ordinal'], raw_buying['time'])
        end
        statement.close

        buyings.each do |b|
          item = MITEM_BY_ID.fetch(b.item_id)
          cost = item.get_price(b.ordinal) * 1000
          total_milli_isu -= cost
          if b.time <= req_time
            gain = item.get_power(b.ordinal) * (req_time - b.time)
            total_milli_isu += gain
          end
        end

        item = MITEM_BY_ID.fetch(item_id)
        need = item.get_price(count_bought + 1) * 1000
        if total_milli_isu < need
          puts 'not enough'
          conn.query('ROLLBACK')
          return false
        end

        statement = conn.prepare('INSERT INTO buying(room_name, item_id, ordinal, time) VALUES(?, ?, ?, ?)')
        statement.execute(room_name, item_id, count_bought + 1, req_time)
        statement.close
      rescue => e
        puts "fail to buy item id=#{item_id} bought=#{count_bought} time=#{req_time}"
        conn.query('ROLLBACK')
        conn.close
        false
      else
        conn.query('COMMIT')
        conn.close
        true
      end
    end

    def get_status(room_name)
      conn = connect_db

      begin
        conn.query('BEGIN')

        current_time = update_room_time(conn, room_name, 0)

        mitems = MITEM_BY_ID

        statement = conn.prepare('SELECT time, isu FROM adding WHERE room_name = ?')
        addings = statement.execute(room_name).map do |fields|
          Adding.new(room_name, fields['time'], fields['isu'])
        end
        statement.close

        statement = conn.prepare('SELECT item_id, ordinal, time FROM buying WHERE room_name = ?')
        buyings = statement.execute(room_name).map do |fields|
          Buying.new(room_name, fields['item_id'], fields['ordinal'], fields['time'])
        end
        statement.close
      rescue => e
        puts e.message
        puts e.backtrace.join("\n")
        conn.query('ROLLBACK')
        conn.close
        nil
      else
        conn.query('COMMIT')

        status = calc_status(current_time, mitems, addings, buyings)

        # calcStatusに時間がかかる可能性があるので タイムスタンプを取得し直す
        latest_time = get_current_time(conn)

        conn.close

        status.time = latest_time
        status
      end
    end

    def calc_status(current_time, mitems, addings, buyings)
      # 1ミリ秒に生産できる椅子の単位をミリ椅子とする
      total_milli_isu = 0
      total_power = 0

      item_power    = {} # ItemID => Power
      item_price    = {} # ItemID => Price
      item_on_sale  = {} # ItemID => OnSale
      item_built    = {} # ItemID => BuiltCount
      item_bought   = {} # ItemID => CountBought
      item_building = {} # ItemID => Buildings
      item_power0   = {} # ItemID => currentTime における Power
      item_built0   = {} # ItemID => currentTime における BuiltCount

      adding_at = {} # Time => currentTime より先の Adding
      buying_at = {} # Time => currentTime より先の Buying

      mitems.each_key do |item_id|
        item_power[item_id] = 0
        item_building[item_id] = []
      end

      addings.each do |a|
        # adding は adding.time に isu を増加させる
        if a.time <= current_time
          total_milli_isu += str2big(a.isu) * 1000
        else
          adding_at[a.time] = a
        end
      end

      buyings.each do |b|
        # buying は 即座に isu を消費し buying.time からアイテムの効果を発揮する
        item_bought[b.item_id] ||= 0
        item_bought[b.item_id] += 1
        m = mitems[b.item_id]
        total_milli_isu -= m.get_price(b.ordinal) * 1000

        if b.time <= current_time
          item_built[b.item_id] ||= 0
          item_built[b.item_id] += 1
          power = m.get_power(item_bought[b.item_id])
          total_milli_isu += power * (current_time - b.time)
          total_power += power
          item_power[b.item_id] ||= 0
          item_power[b.item_id] += power
        else
          buying_at[b.time] ||= []
          buying_at[b.time] << b
        end
      end

      mitems.each_value do |m|
        item_power0[m.item_id] = big2exp(item_power[m.item_id])
        item_built0[m.item_id] = item_built[m.item_id]
        price = m.get_price((item_bought[m.item_id] || 0) + 1)
        item_price[m.item_id] = price
        if total_milli_isu >= price * 1000
          item_on_sale[m.item_id] = 0 # 0 は 時刻 currentTime で購入可能であることを表す
        end
      end

      schedule = [
        Schedule.new(current_time, big2exp(total_milli_isu), big2exp(total_power)),
      ]

      # currentTime から 1000 ミリ秒先までシミュレーションする
      (current_time + 1).upto(current_time + 1000).each do |t|
        total_milli_isu += total_power
        updated = false

        # 時刻 t で発生する adding を計算する
        unless adding_at[t].nil?
          updated = true
          total_milli_isu += str2big(adding_at[t].isu) * 1000
        end

        # 時刻 t で発生する buying を計算する
        if !buying_at[t].nil? && !buying_at[t].empty?
          updated = true
          updated_id = {}
          buying_at[t].each do |b|
            m = mitems[b.item_id]
            updated_id[b.item_id] = true
            item_built[b.item_id] ||= 0
            item_built[b.item_id] += 1
            power = m.get_power(b.ordinal)
            item_power[b.item_id] ||= 0
            item_power[b.item_id] += power
            total_power += power
          end
          updated_id.each_key do |id|
            item_building[id] ||= []
            item_building[id] << Building.new(t, item_built[id], big2exp(item_power[id]))
          end
        end

        if updated
          schedule << Schedule.new(t, big2exp(total_milli_isu), big2exp(total_power))
        end

        # 時刻 t で購入可能になったアイテムを記録する
        mitems.each_key do |item_id|
          next unless item_on_sale[item_id].nil?

          if total_milli_isu >= item_price[item_id] * 1000
            item_on_sale[item_id] = t
          end
        end
      end

      gs_adding = adding_at.values.map { |a| a }

      gs_items = mitems.keys.map { |item_id| Item.new(item_id, item_bought[item_id], item_built0[item_id], big2exp(item_price[item_id]), item_power0[item_id], item_building[item_id]) }

      gs_on_sale = item_on_sale.map { |item_id, t| OnSale.new(item_id, t) }

      GameStatus.new(0, gs_adding, schedule, gs_items, gs_on_sale)
    end

    private

    def connect_db
      Mysql2::Client.new(
        host: ENV.fetch('ISU_DB_HOST') { '127.0.0.1' },
        port: ENV.fetch('ISU_DB_PORT') { '3306' },
        username: ENV.fetch('ISU_DB_USER') { 'root' },
        password: ENV.fetch('ISU_DB_PASSWORD') { '' },
        database: 'isudb',
        encoding: 'utf8mb4'
      )
    end
  end

  def initialize(app = nil)
    @app = app
  end

  def call(env)
    return @app.call(env) unless websocket?(env)

    ws = Faye::WebSocket.new(env)

    path = env['PATH_INFO']
    room_name = path[4, path.length - 4]

    status = self.class.get_status(room_name)
    ws.send(status.to_json)

    ws.on :message do |event|
      raw_req = JSON.parse(event.data)
      req = GameRequest.new(
        raw_req['request_id'],
        raw_req['action'],
        raw_req['time'],
        raw_req['isu'],
        raw_req['item_id'] || 0,
        raw_req['count_bought'] || 0
      )

      case req.action
      when 'addIsu'
        success = self.class.add_isu(room_name, self.class.str2big(req.isu), req.time)
      when 'buyItem'
        success = self.class.buy_item(room_name, req.item_id, req.count_bought, req.time)
      else
        return
      end

      if success
        # GameResponse を返却する前に 反映済みの GameStatus を返す
        status = self.class.get_status(room_name)
        ws.send(status.to_json)
      end

      res = GameResponse.new(req.request_id, success)
      ws.send(res.to_json)
    end

    ws.on :close do |event|
      ws = nil
    end

    ticker = Concurrent::Channel.ticker(0.5)
    Concurrent::Channel.go do
      ticker.each do |tick|
        if tick
          status = self.class.get_status(room_name)
          ws.send(status.to_json)
        end
      end
    end

    ws.rack_response
  end

  private

  def websocket?(env)
    path = env['PATH_INFO']

    path =~ %r{\A/ws/} && Faye::WebSocket.websocket?(env)
  end
end
