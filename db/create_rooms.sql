DROP TABLE rooms IF EXISTS;
CREATE TABLE `rooms` (
  `room_name` varchar(191) COLLATE utf8mb4_bin NOT NULL,
  `host_id` int(8) NOT NULL,
  PRIMARY KEY (`room_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
