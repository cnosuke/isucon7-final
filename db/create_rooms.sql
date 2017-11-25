CREATE TABLE `rooms` (
  `room_name` varchar(191) COLLATE utf8mb4_bin NOT NULL,
  `host_id` int(8) NOT NULL,
  PRIMARY KEY (`room_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO rooms VALUES('dummy01', 0);
INSERT INTO rooms VALUES('dummy02', 0);
INSERT INTO rooms VALUES('dummy03', 0);
INSERT INTO rooms VALUES('dummy10', 1);
INSERT INTO rooms VALUES('dummy20', 2);
INSERT INTO rooms VALUES('dummy30', 3);

CREATE INDEX idx_rooms_host ON rooms (host_id) USING BTREE;;
