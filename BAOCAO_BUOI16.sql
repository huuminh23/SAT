CREATE PROC BAOCAO_BUOI16
@DAUKY DATE,
@CUOIKY DATE
AS
BEGIN
---TIỀN GỬI KHÔNG KỲ HẠN
		DECLARE @TBL_BAOCAO TABLE
		(
		[TIÊU CHÍ CHUNG]	NVARCHAR(500),
		[TIÊU CHÍ]		NVARCHAR(500),
		[SỐ TIỀN 1]		NUMERIC(18,2),
		[TỶ LỆ 1]			NUMERIC(18,2),
		[SỐ TIỀN 2]			NUMERIC(18,2),
		[TỶ LỆ 2]			NUMERIC(18,2)
		)

		 --Thêm dòng đầu tiên vào bảng tạm
		INSERT INTO @TBL_BAOCAO 
		VALUES (N'THEO LOẠI TIỀN GỬI', N'TIỀN GỬI KHÔNG KỲ HẠN', 0, 100, 0, 100);

		-- Sử dụng CTE để lấy các thông tin về tiền gửi không kỳ hạn
		WITH LOAI_TIEN_KHONG_KY_HAN AS (
			SELECT 'VND' AS LOAI_TIEN, N'.1Tiền gửi không kỳ hạn bằng VND' AS LOAI_TIEN_GUI
			UNION ALL
			SELECT 'USD', N'.2 Tiền gửi không kỳ hạn bằng ngoại tệ'
			UNION ALL
			SELECT 'EUR', N'.2 Tiền gửi không kỳ hạn bằng ngoại tệ'
		)
		-- Lấy thông tin về số tiền gửi, tỷ lệ và số tiền
		INSERT INTO @TBL_BAOCAO
		SELECT 
		N'TIỀN GỬI KHÔNG KỲ HẠN', 
		CONCAT('I.', LT1.LOAI_TIEN_GUI) AS LOAI_TIEN_GUI,
		-- Số tiền 1 với điều kiện THOIGIAN_GIAODICH <= @DAUKY
		COALESCE(SUM(CASE 
                    WHEN KQ1.LOAI_TIEN = 'VND' THEN KQ1.SODU_CUOI
                    WHEN KQ1.LOAI_TIEN = 'USD' THEN KQ1.SODU_CUOI * 25000
                    WHEN KQ1.LOAI_TIEN = 'EUR' THEN KQ1.SODU_CUOI * 33000
                    ELSE 0
                END), 0) AS [SỐ TIỀN 1],
		-- TỶ LỆ 1
		0 AS [TỶ LỆ 1],
		-- Số tiền 2 với điều kiện THOIGIAN_GIAODICH <= @CUOIKY
		COALESCE(SUM(CASE 
                    WHEN KQ2.LOAI_TIEN = 'VND' THEN KQ2.SODU_CUOI
                    WHEN KQ2.LOAI_TIEN = 'USD' THEN KQ2.SODU_CUOI * 25000
                    WHEN KQ2.LOAI_TIEN = 'EUR' THEN KQ2.SODU_CUOI * 33000
                    ELSE 0
                END), 0) AS [SỐ TIỀN 2],
		-- Tỷ lệ 2 
		0 AS [TỶ LỆ 2]
			FROM LOAI_TIEN_KHONG_KY_HAN LT1
			LEFT JOIN (
				-- Lấy số tiền và tỷ lệ với điều kiện THOIGIAN_GIAODICH <= @DAUKY
				SELECT 
					LOAI_TIEN,
					SODU_CUOI
				FROM (
					SELECT 
						LOAI_TIEN,
						SODU_CUOI,
						ROW_NUMBER() OVER (
							PARTITION BY MA_TAIKHOAN_THANHTOAN, LOAI_TIEN
							ORDER BY THOIGIAN_GIAODICH DESC
						) AS RN
					FROM TIENGUI_THANHTOAN
					WHERE THOIGIAN_GIAODICH <= @DAUKY -- Lọc theo @DAUKY
				) AS TMP
				WHERE RN = 1
			) AS KQ1 ON LT1.LOAI_TIEN = KQ1.LOAI_TIEN

			LEFT JOIN (
				-- Lấy số tiền và tỷ lệ với điều kiện THOIGIAN_GIAODICH <= @CUOIKY
				SELECT 
					LOAI_TIEN,
					SODU_CUOI
				FROM (
					SELECT 
						LOAI_TIEN,
						SODU_CUOI,
						ROW_NUMBER() OVER (
							PARTITION BY MA_TAIKHOAN_THANHTOAN, LOAI_TIEN
							ORDER BY THOIGIAN_GIAODICH DESC
						) AS RN
					FROM TIENGUI_THANHTOAN
					WHERE THOIGIAN_GIAODICH <= @CUOIKY -- Lọc theo @CUOIKY
				) AS TMP
				WHERE RN = 1
			) AS KQ2 ON LT1.LOAI_TIEN = KQ2.LOAI_TIEN
	
			GROUP BY LT1.LOAI_TIEN_GUI;
			 --Sử dụng CTE để lấy các thông tin về tiền gửi có kỳ hạn
			 INSERT INTO @TBL_BAOCAO 
			VALUES (N' ', N'TIỀN GỬI CÓ KỲ HẠN', 0, 100, 0, 100);

---- TIỀN GỬI CÓ KỲ HẠN 
	-- Bảng loại tiền mặc định (có thêm ngoại lệ)
		WITH LOAI_TIEN_CO_KY_HAN AS (
			SELECT 'VND' AS LOAI_TIEN, N'.1 Tiền gửi có kỳ hạn bằng VND' AS LOAI_TIEN_GUI
			UNION ALL
			SELECT 'USD', N'.2 Tiền gửi có kỳ hạn bằng ngoại tệ'
			UNION ALL
			SELECT 'EUR', N'.2 Tiền gửi có kỳ hạn bằng ngoại tệ'
		)
		-- Thực hiện chèn dữ liệu vào bảng tạm
		INSERT INTO @TBL_BAOCAO
		SELECT 
			N'TIỀN GỬI CÓ KỲ HẠN',  -- Cột "TIÊU CHÍ CHUNG" để trống
			CONCAT('II.', LT.LOAI_TIEN_GUI) AS LOAI_TIEN_GUI,
			-- Số tiền 1: Tính cho khoảng thời gian <= @DAUKY
			COALESCE(
				(SELECT SUM(CASE 
							WHEN LOAITIEN = 'VND' THEN SOTIEN
							WHEN LOAITIEN = 'USD' THEN SOTIEN * 25000
							WHEN LOAITIEN = 'EUR' THEN SOTIEN * 33000
							ELSE SOTIEN * 20000 -- Quy đổi mặc định cho ngoại lệ
						END) 
				 FROM TIENGUI_TIETKIEM 
				 WHERE NGAY_GUI <= @DAUKY AND NGAY_DENHAN > @DAUKY AND LOAITIEN = LT.LOAI_TIEN), 
				0
			) +
			COALESCE(
				(SELECT SUM(CASE 
							WHEN LOAITIEN = 'VND' THEN SOTIEN
							WHEN LOAITIEN = 'USD' THEN SOTIEN * 25000
							WHEN LOAITIEN = 'EUR' THEN SOTIEN * 33000
							ELSE SOTIEN * 20000 -- Quy đổi mặc định cho ngoại lệ
						END) 
				 FROM TIENGUI_COKYHAN 
				 WHERE NGAY_GUI <= @DAUKY AND NGAY_DENHAN > @DAUKY AND LOAITIEN = LT.LOAI_TIEN), 
				0
			) AS SO_TIEN_1,
			0 AS TY_LE_1,  -- Chưa có logic tính tỷ lệ
			-- Số tiền 2: Tính cho khoảng thời gian <= @CUOIKY
			COALESCE(
				(SELECT SUM(CASE 
							WHEN LOAITIEN = 'VND' THEN SOTIEN
							WHEN LOAITIEN = 'USD' THEN SOTIEN * 25000
							WHEN LOAITIEN = 'EUR' THEN SOTIEN * 33000
							ELSE SOTIEN * 20000 -- Quy đổi mặc định cho ngoại lệ
						END) 
				 FROM TIENGUI_TIETKIEM 
				 WHERE NGAY_GUI <= @CUOIKY AND NGAY_DENHAN > @CUOIKY AND LOAITIEN = LT.LOAI_TIEN), 
				0
			) +
			COALESCE(
				(SELECT SUM(CASE 
							WHEN LOAITIEN = 'VND' THEN SOTIEN
							WHEN LOAITIEN = 'USD' THEN SOTIEN * 25000
							WHEN LOAITIEN = 'EUR' THEN SOTIEN * 33000
							ELSE SOTIEN * 20000 -- Quy đổi mặc định cho ngoại lệ
						END) 
				 FROM TIENGUI_COKYHAN 
				 WHERE NGAY_GUI <= @CUOIKY AND NGAY_DENHAN > @CUOIKY AND LOAITIEN = LT.LOAI_TIEN), 
				0
			) AS SO_TIEN_2,
			0 AS TY_LE_2  -- Chưa có logic tính tỷ lệ
		FROM LOAI_TIEN_CO_KY_HAN LT
		GROUP BY LT.LOAI_TIEN_GUI,LT.LOAI_TIEN;

-------TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP
--------ĐẦU KỲ 
INSERT INTO @TBL_BAOCAO 
VALUES (N'', N'TIỀN GỬI CỦA CÁC TỔ CHỨC KINH TẾ', 0, 100, 0, 100);

INSERT INTO @TBL_BAOCAO
SELECT 
    N'TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP',
    CONCAT('III.',ID,' ', TEN_LOAIHINH_DOANHNGHIEP),
    0, 0, 0, 0
FROM LOAIHINH_DOANHNGHIEP;

UPDATE @TBL_BAOCAO
SET		[SỐ TIỀN 1] = ISNULL(TONGHOP.TONG_SO_TIEN, 0)
FROM @TBL_BAOCAO A
LEFT JOIN 
(SELECT 
    D.TEN_LOAIHINH_DOANHNGHIEP,
    COALESCE(
        SUM(
            CASE 
                WHEN H.LOAITIEN = 'USD' THEN H.SOTIEN * 25000
                WHEN H.LOAITIEN = 'EUR' THEN H.SOTIEN * 33000
                ELSE H.SOTIEN
            END
        ), 0
    ) + COALESCE(SUM(T.SODU_CUOI), 0) AS TONG_SO_TIEN
FROM 
    KHACHHANG K
LEFT JOIN 
    TIENGUI_COKYHAN H 
ON K.MA_KHACHHANG = H.MA_KHACHHANG AND H.NGAY_GUI <= @DAUKY AND  NGAY_DENHAN > @DAUKY
LEFT JOIN (
    SELECT 
        MA_TAIKHOAN_THANHTOAN,
        SODU_CUOI
    FROM (
        SELECT 
            SODU_CUOI,
            MA_TAIKHOAN_THANHTOAN,
            THOIGIAN_GIAODICH,
            ROW_NUMBER() OVER(
                PARTITION BY MA_TAIKHOAN_THANHTOAN
                ORDER BY THOIGIAN_GIAODICH DESC
            ) AS RN1
        FROM 
            TIENGUI_THANHTOAN
        WHERE 
            THOIGIAN_GIAODICH <= @DAUKY
    ) AS TONG_HOP
    WHERE RN1 = 1
) T 
ON K.MA_TAIKHOAN_THANHTOAN = T.MA_TAIKHOAN_THANHTOAN
LEFT JOIN 
    LOAIHINH_DOANHNGHIEP D 
    ON K.MA_LOAIHINH_KHACHHANG = D.MA_LOAIHINH_DOANHNGHIEP
GROUP BY 
    D.TEN_LOAIHINH_DOANHNGHIEP) TONGHOP
ON A.[TIÊU CHÍ] LIKE '%' + TONGHOP.TEN_LOAIHINH_DOANHNGHIEP + '%'
WHERE [TIÊU CHÍ CHUNG] = N'TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP'
---- CUỐI KỲ
INSERT INTO @TBL_BAOCAO
SELECT 
    N'TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP',
    CONCAT('III.',ID,' ', TEN_LOAIHINH_DOANHNGHIEP),
    0, 0, 0, 0
FROM LOAIHINH_DOANHNGHIEP;

UPDATE @TBL_BAOCAO
SET		[SỐ TIỀN 2] = ISNULL(TONGHOP.TONG_SO_TIEN, 0)
FROM @TBL_BAOCAO A
LEFT JOIN 
(SELECT 
    D.TEN_LOAIHINH_DOANHNGHIEP,
    COALESCE(
        SUM(
            CASE 
                WHEN H.LOAITIEN = 'USD' THEN H.SOTIEN * 25000
                WHEN H.LOAITIEN = 'EUR' THEN H.SOTIEN * 33000
                ELSE H.SOTIEN
            END
        ), 0
    ) + COALESCE(SUM(T.SODU_CUOI), 0) AS TONG_SO_TIEN
FROM 
    KHACHHANG K
LEFT JOIN 
    TIENGUI_COKYHAN H 
ON K.MA_KHACHHANG = H.MA_KHACHHANG AND H.NGAY_GUI <= @CUOIKY AND  NGAY_DENHAN > @CUOIKY
LEFT JOIN (
    SELECT 
        MA_TAIKHOAN_THANHTOAN,
        SODU_CUOI
    FROM (
        SELECT 
            SODU_CUOI,
            MA_TAIKHOAN_THANHTOAN,
            THOIGIAN_GIAODICH,
            ROW_NUMBER() OVER(
                PARTITION BY MA_TAIKHOAN_THANHTOAN
                ORDER BY THOIGIAN_GIAODICH DESC
            ) AS RN1
        FROM 
            TIENGUI_THANHTOAN
        WHERE 
            THOIGIAN_GIAODICH <= @CUOIKY
    ) AS TONG_HOP
    WHERE RN1 = 1
) T 
ON K.MA_TAIKHOAN_THANHTOAN = T.MA_TAIKHOAN_THANHTOAN
LEFT JOIN 
    LOAIHINH_DOANHNGHIEP D 
    ON K.MA_LOAIHINH_KHACHHANG = D.MA_LOAIHINH_DOANHNGHIEP
GROUP BY 
    D.TEN_LOAIHINH_DOANHNGHIEP) TONGHOP
ON A.[TIÊU CHÍ] LIKE '%' + TONGHOP.TEN_LOAIHINH_DOANHNGHIEP + '%'
WHERE [TIÊU CHÍ CHUNG] = N'TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP'

----- TIỀN GỬI CÁ NHÂN
INSERT INTO @TBL_BAOCAO 
VALUES (N'TIỀN GỬI THEO ĐỐI TƯỢNG CÁ NHÂN', N'TIỀN GỬI CỦA CÁC CÁ NHÂN', 0, 100, 0, 100);
DECLARE @SL NUMERIC; -- Sửa từ @ST thành @SL
SET @SL = (
    SELECT 
        COALESCE(
            SUM(
                CASE 
                    WHEN H.LOAITIEN = 'USD' THEN H.SOTIEN * 25000
                    WHEN H.LOAITIEN = 'EUR' THEN H.SOTIEN * 33000
                    ELSE H.SOTIEN
                END
            ), 0
        ) + COALESCE(SUM(SODU_CUOI), 0)
    FROM KHACHHANG K
    LEFT JOIN TIENGUI_TIETKIEM H
        ON K.MA_KHACHHANG = H.MA_KHACHHANG 
        AND H.NGAY_GUI <= @DAUKY 
        AND H.NGAY_DENHAN > @DAUKY
    LEFT JOIN (
        SELECT 
            MA_TAIKHOAN_THANHTOAN,
            SODU_CUOI
        FROM (
            SELECT 
                SODU_CUOI,
                MA_TAIKHOAN_THANHTOAN,
                ROW_NUMBER() OVER (
                    PARTITION BY MA_TAIKHOAN_THANHTOAN
                    ORDER BY THOIGIAN_GIAODICH DESC
                ) AS RN1
            FROM TIENGUI_THANHTOAN
            WHERE THOIGIAN_GIAODICH <= @DAUKY
        ) AS TONG_HOP
        WHERE RN1 = 1
    ) T 
        ON K.MA_TAIKHOAN_THANHTOAN = T.MA_TAIKHOAN_THANHTOAN
    WHERE K.MA_LOAI_KHACHHANG = 'CN'
);
UPDATE @TBL_BAOCAO 
SET [SỐ TIỀN 1] = @SL 
WHERE [TIÊU CHÍ] = N'TIỀN GỬI CỦA CÁC CÁ NHÂN';

----CUỐI KỲ
DECLARE @SL1 NUMERIC; -- Sửa từ @ST thành @SL
SET @SL1 = (
    SELECT 
        COALESCE(
            SUM(
                CASE 
                    WHEN H.LOAITIEN = 'USD' THEN H.SOTIEN * 25000
                    WHEN H.LOAITIEN = 'EUR' THEN H.SOTIEN * 33000
                    ELSE H.SOTIEN
                END
            ), 0
        ) + COALESCE(SUM(SODU_CUOI), 0)
    FROM KHACHHANG K
    LEFT JOIN TIENGUI_TIETKIEM H
        ON K.MA_KHACHHANG = H.MA_KHACHHANG 
        AND H.NGAY_GUI <= @CUOIKY
        AND H.NGAY_DENHAN > @CUOIKY
    LEFT JOIN (
        SELECT 
            MA_TAIKHOAN_THANHTOAN,
            SODU_CUOI
        FROM (
            SELECT 
                SODU_CUOI,
                MA_TAIKHOAN_THANHTOAN,
                ROW_NUMBER() OVER (
                    PARTITION BY MA_TAIKHOAN_THANHTOAN
                    ORDER BY THOIGIAN_GIAODICH DESC
                ) AS RN1
            FROM TIENGUI_THANHTOAN
            WHERE THOIGIAN_GIAODICH <= @CUOIKY
        ) AS TONG_HOP
        WHERE RN1 = 1
    ) T 
        ON K.MA_TAIKHOAN_THANHTOAN = T.MA_TAIKHOAN_THANHTOAN
    WHERE K.MA_LOAI_KHACHHANG = 'CN'
);
UPDATE @TBL_BAOCAO 
SET [SỐ TIỀN 2] = @SL1 
WHERE [TIÊU CHÍ] = N'TIỀN GỬI CỦA CÁC CÁ NHÂN';

----TÍNH PHẦN TRĂM
-- Khai báo các biến lưu tổng số tiền
DECLARE @TONG_TIEN_KHONGKH NUMERIC;
DECLARE @TONG_TIEN_COKH NUMERIC;
DECLARE @TONG_TIEN_GUI_CAC_CAI_NHAN NUMERIC;
DECLARE @TONG_TIEN_GUI_DOANH_NGHIEP NUMERIC;

-- Tính tổng số tiền gửi cho từng nhóm
SET @TONG_TIEN_KHONGKH = (
    SELECT SUM([SỐ TIỀN 1])
    FROM @TBL_BAOCAO
    WHERE [TIÊU CHÍ CHUNG] = N'TIỀN GỬI KHÔNG KỲ HẠN'
);
SET @TONG_TIEN_COKH = (
    SELECT SUM([SỐ TIỀN 1])
    FROM @TBL_BAOCAO
    WHERE [TIÊU CHÍ CHUNG] = N'TIỀN GỬI CÓ KỲ HẠN'
);

-- Tính tổng tiền gửi của các cá nhân
SET @TONG_TIEN_GUI_CAC_CAI_NHAN = (
    SELECT SUM([SỐ TIỀN 1])
    FROM @TBL_BAOCAO
    WHERE [TIÊU CHÍ CHUNG] = N'TIỀN GỬI THEO ĐỐI TƯỢNG CÁ NHÂN'
);

-- Tính tổng tiền gửi của doanh nghiệp
SET @TONG_TIEN_GUI_DOANH_NGHIEP = (
    SELECT SUM([SỐ TIỀN 1])
    FROM @TBL_BAOCAO
    WHERE [TIÊU CHÍ CHUNG] = N'TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP'
);

-- Cập nhật tỷ lệ 1 và tỷ lệ 2 vào bảng @TBL_BAOCAO
UPDATE @TBL_BAOCAO
SET 
    -- Cập nhật tỷ lệ 1: Tính tỷ lệ so với tổng tiền gửi (theo loại tiền gửi)
    [TỶ LỆ 1] = 
        CASE 
            WHEN [TIÊU CHÍ CHUNG] = N'TIỀN GỬI KHÔNG KỲ HẠN'
            THEN ([SỐ TIỀN 1] / @TONG_TIEN_KHONGKH) * 100
            WHEN [TIÊU CHÍ CHUNG] = N'TIỀN GỬI CÓ KỲ HẠN'
            THEN ([SỐ TIỀN 1] / @TONG_TIEN_COKH) * 100
            ELSE 0
        END,
    
    -- Cập nhật tỷ lệ 2: Tính tỷ lệ theo đối tượng (doanh nghiệp hoặc cá nhân)
    [TỶ LỆ 2] = 
        CASE
            WHEN [TIÊU CHÍ CHUNG] = N'TIỀN GỬI KHÔNG KỲ HẠN'
            THEN ([SỐ TIỀN 1] / @TONG_TIEN_GUI_CAC_CAI_NHAN) * 100
            WHEN [TIÊU CHÍ CHUNG] = N'TIỀN GỬI CÓ KỲ HẠN'
            THEN ([SỐ TIỀN 1] / @TONG_TIEN_GUI_DOANH_NGHIEP) * 100
            ELSE 0
        END
WHERE [TIÊU CHÍ CHUNG] IN (N'TIỀN GỬI KHÔNG KỲ HẠN', N'TIỀN GỬI CÓ KỲ HẠN', N'TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP', N'TIỀN GỬI CỦA CÁ CÁ NHÂN');
UPDATE @TBL_BAOCAO
SET 
    -- Cập nhật tỷ lệ 1: Tính tỷ lệ so với tổng tiền gửi (theo loại tiền gửi)
    [TỶ LỆ 1] = 
        CASE 
            WHEN [TIÊU CHÍ CHUNG] = N'TIỀN GỬI THEO ĐÓI TƯỢNG CÁ NHÂN'
            THEN ([SỐ TIỀN 1] / @TONG_TIEN_KHONGKH) * 100
            WHEN [TIÊU CHÍ CHUNG] = N'TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP'
            THEN ([SỐ TIỀN 1] / @TONG_TIEN_COKH) * 100
            ELSE 0
        END,
    
    -- Cập nhật tỷ lệ 2: Tính tỷ lệ theo đối tượng (doanh nghiệp hoặc cá nhân)
    [TỶ LỆ 2] = 
        CASE
            WHEN [TIÊU CHÍ CHUNG] = N'TIỀN GỬI THEO ĐÓI TƯỢNG CÁ NHÂN'
            THEN ([SỐ TIỀN 1] / @TONG_TIEN_GUI_CAC_CAI_NHAN) * 100
            WHEN [TIÊU CHÍ CHUNG] = N'TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP'
            THEN ([SỐ TIỀN 1] / @TONG_TIEN_GUI_DOANH_NGHIEP) * 100
            ELSE 0
        END
WHERE [TIÊU CHÍ CHUNG] IN (N'TIỀN GỬI KHÔNG KỲ HẠN', N'TIỀN GỬI CÓ KỲ HẠN', N'TIỀN GỬI THEO ĐỐI TƯỢNG LOẠI HÌNH DOANH NGHIỆP', N'TIỀN GỬI CỦA CÁ CÁ NHÂN');
-- Cập nhật số tiền gửi cho loại TIỀN GỬI KHÔNG KỲ HẠN
UPDATE @TBL_BAOCAO
SET 
    [SỐ TIỀN 1] = @TONG_TIEN_KHONGKH, 
    [SỐ TIỀN 2] = @TONG_TIEN_KHONGKH
WHERE [TIÊU CHÍ] = N'TIỀN GỬI KHÔNG KỲ HẠN';

-- Cập nhật số tiền gửi cho loại TIỀN GỬI CÓ KỲ HẠN
UPDATE @TBL_BAOCAO
SET 
    [SỐ TIỀN 1] = @TONG_TIEN_COKH, 
    [SỐ TIỀN 2] = @TONG_TIEN_COKH
WHERE [TIÊU CHÍ] = N'TIỀN GỬI CÓ KỲ HẠN';

-- Cập nhật số tiền gửi cho loại TIỀN GỬI CỦA CÁC TỔ CHỨC KINH TẾ
UPDATE @TBL_BAOCAO
SET 
    [SỐ TIỀN 1] = @TONG_TIEN_GUI_DOANH_NGHIEP, 
    [SỐ TIỀN 2] = @TONG_TIEN_GUI_DOANH_NGHIEP
WHERE [TIÊU CHÍ] = N'TIỀN GỬI CỦA CÁC TỔ CHỨC KINH TẾ';

-- Cập nhật số tiền gửi cho loại TIỀN GỬI CỦA CÁC ĐỐI TƯỢNG CÁ NHÂN
UPDATE @TBL_BAOCAO
SET 
    [SỐ TIỀN 1] = @TONG_TIEN_GUI_CAC_CAI_NHAN, 
    [SỐ TIỀN 2] = @TONG_TIEN_GUI_CAC_CAI_NHAN
WHERE [TIÊU CHÍ] = N'TIỀN GỬI CỦA CÁC ĐỐI TƯỢNG CÁ NHÂN';

-- Hiển thị kết quả
SELECT * FROM @TBL_BAOCAO;

END;

EXEC BAOCAO_BUOI16 '2024-06-30','2023-12-31'

