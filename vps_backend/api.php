<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: *");
header("Access-Control-Allow-Methods: *");
header("Content-Type: application/json");

ini_set('display_errors', 0);
error_reporting(E_ALL);

date_default_timezone_set('Asia/Kolkata');

$host = "localhost";
$user = "daily_mart";
$pass = "DWZYHcAxSars3di8";
$dbname = "daily_mart";

$conn = @new mysqli($host, $user, $pass, $dbname);

if ($conn->connect_error) {
    echo json_encode(["success" => false, "error" => "DB Connection Failed"]);
    exit();
}

$action = isset($_GET['action']) ? $_GET['action'] : '';
$rawInput = @file_get_contents('php://input');
$input = json_decode($rawInput, true);
if (!is_array($input)) $input = array();

// 1. Auto-check & create address_json column in customers table if missing
$colCheckAddr = $conn->query("SHOW COLUMNS FROM customers LIKE 'address_json'");
if (!$colCheckAddr || $colCheckAddr->num_rows == 0) {
    @$conn->query("ALTER TABLE customers ADD COLUMN address_json LONGTEXT DEFAULT NULL");
}

// 2. Auto-check & create payment & order columns in messages table if missing
$colCheckPay = $conn->query("SHOW COLUMNS FROM messages LIKE 'payment_status'");
if (!$colCheckPay || $colCheckPay->num_rows == 0) {
    @$conn->query("ALTER TABLE messages ADD COLUMN payment_status VARCHAR(20) DEFAULT 'unpaid', ADD COLUMN payment_utr VARCHAR(100) DEFAULT NULL, ADD COLUMN paid_amount DECIMAL(10,2) DEFAULT 0.00, ADD COLUMN paid_at VARCHAR(50) DEFAULT NULL");
}

$colCheckAmt = $conn->query("SHOW COLUMNS FROM messages LIKE 'order_amount'");
if (!$colCheckAmt || $colCheckAmt->num_rows == 0) {
    @$conn->query("ALTER TABLE messages ADD COLUMN order_amount DECIMAL(10,2) DEFAULT 0.00");
}

$colCheckBill = $conn->query("SHOW COLUMNS FROM messages LIKE 'bill_image'");
if (!$colCheckBill || $colCheckBill->num_rows == 0) {
    @$conn->query("ALTER TABLE messages ADD COLUMN bill_image LONGTEXT DEFAULT NULL");
}

// 3. Auto-check & create delivery status tracking columns in messages table
$colCheckDelStatus = $conn->query("SHOW COLUMNS FROM messages LIKE 'delivery_status'");
if (!$colCheckDelStatus || $colCheckDelStatus->num_rows == 0) {
    @$conn->query("ALTER TABLE messages ADD COLUMN delivery_status VARCHAR(50) DEFAULT 'pending', ADD COLUMN delivered_by VARCHAR(100) DEFAULT NULL, ADD COLUMN picked_up_at VARCHAR(50) DEFAULT NULL, ADD COLUMN delivered_at VARCHAR(50) DEFAULT NULL, ADD COLUMN cancel_reason VARCHAR(255) DEFAULT NULL, ADD COLUMN cancelled_at VARCHAR(50) DEFAULT NULL");
}

// 4. Auto-check & create seller_sliders table in database
$conn->query("CREATE TABLE IF NOT EXISTS seller_sliders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    tag VARCHAR(255) DEFAULT 'SPECIAL OFFER 🏷️',
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    bg_image_url LONGTEXT DEFAULT NULL,
    tag_bg_color VARCHAR(50) DEFAULT '#10B981',
    tag_shape VARCHAR(50) DEFAULT 'pill',
    title_color VARCHAR(50) DEFAULT '#FFFFFF',
    desc_color VARCHAR(50) DEFAULT '#E2E8F0',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

// 5. Auto-check & create delivery_boys table in database
$conn->query("CREATE TABLE IF NOT EXISTS delivery_boys (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    mobile VARCHAR(20) NOT NULL,
    vehicle VARCHAR(100) DEFAULT 'Bike',
    location VARCHAR(255) DEFAULT NULL,
    role VARCHAR(50) DEFAULT 'delivery_boy',
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

$colCheckDelLoc = $conn->query("SHOW COLUMNS FROM delivery_boys LIKE 'location'");
if (!$colCheckDelLoc || $colCheckDelLoc->num_rows == 0) {
    @$conn->query("ALTER TABLE delivery_boys ADD COLUMN location VARCHAR(255) DEFAULT NULL");
}

$colCheckSelLoc = $conn->query("SHOW COLUMNS FROM sellers LIKE 'location'");
if (!$colCheckSelLoc || $colCheckSelLoc->num_rows == 0) {
    @$conn->query("ALTER TABLE sellers ADD COLUMN location VARCHAR(255) DEFAULT NULL");
}

// 6. Auto-check & create locations table in database
$conn->query("CREATE TABLE IF NOT EXISTS locations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

// 7. Auto-check & create seller_products table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    unit VARCHAR(50) NOT NULL DEFAULT 'Pcs',
    category VARCHAR(255) DEFAULT NULL,
    qty INT NOT NULL DEFAULT 1,
    rate DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    image_url LONGTEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckQty = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'qty'");
if (!$colCheckQty || $colCheckQty->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_products ADD COLUMN qty INT NOT NULL DEFAULT 1");
}

$colCheckProdImg = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'image_url'");
if (!$colCheckProdImg || $colCheckProdImg->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_products ADD COLUMN image_url LONGTEXT DEFAULT NULL");
}

// 8. Auto-check & create seller_units table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_units (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    unit_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

// 9. Auto-check & create app_settings table for Global Header Theme Sync if missing
@$conn->query("CREATE TABLE IF NOT EXISTS app_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value LONGTEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckCat = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'category'");
if (!$colCheckCat || $colCheckCat->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_products ADD COLUMN category VARCHAR(255) DEFAULT NULL");
}

// 10. Auto-check & create seller_categories table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    image_url LONGTEXT DEFAULT NULL,
    color VARCHAR(50) DEFAULT '#8B5CF6',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckCatColor = $conn->query("SHOW COLUMNS FROM seller_categories LIKE 'color'");
if (!$colCheckCatColor || $colCheckCatColor->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_categories ADD COLUMN color VARCHAR(50) DEFAULT '#8B5CF6'");
}

if ($action == 'get-header-theme') {
    $res = $conn->query("SELECT setting_value FROM app_settings WHERE setting_key = 'global_header_theme'");
    if ($res && $row = $res->fetch_assoc()) {
        $themeConfig = json_decode($row['setting_value'], true);
        if (is_array($themeConfig)) {
            echo json_encode(["success" => true, "theme" => $themeConfig]);
            exit();
        }
    }
    echo json_encode(["success" => true, "theme" => null]);
    exit();
} elseif ($action == 'update-header-theme') {
    $themeConfig = isset($input) && is_array($input) ? $input : array();
    $jsonVal = json_encode($themeConfig);

    $stmt = $conn->prepare("INSERT INTO app_settings (setting_key, setting_value) VALUES ('global_header_theme', ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)");
    if ($stmt) {
        $stmt->bind_param("s", $jsonVal);
        $stmt->execute();
    }
    echo json_encode(["success" => true, "message" => "Header theme saved in database"]);
    exit();
} elseif ($action == 'customer-login') {
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $address_json = isset($input['address_json']) ? (is_array($input['address_json']) ? json_encode($input['address_json']) : trim($input['address_json'])) : '';

    $cName = 'Customer';
    $cAddr = '';

    if (!empty($mobile)) {
        $digits = preg_replace('/[^0-9]/', '', $mobile);
        $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
        $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

        $chkRes = $conn->query("SELECT name, address_json FROM customers WHERE mobile = '$mobile' OR mobile LIKE '$escapedLike' ORDER BY id DESC LIMIT 1");
        if ($chkRes && $chkRow = $chkRes->fetch_assoc()) {
            $exName = trim($chkRow['name'] ?? '');
            if (!empty($exName) && $exName !== 'Customer' && strpos($exName, 'Customer') !== 0) {
                $cName = $exName;
            }
            if (!empty($chkRow['address_json'])) {
                $cAddr = $chkRow['address_json'];
            }
        }

        if (!empty($name) && $name !== 'Customer' && strpos($name, 'Customer') !== 0) {
            $cName = $name;
        }
        if (!empty($address_json)) {
            $cAddr = $address_json;
        }

        if (!empty($cName) || !empty($cAddr)) {
            $stmt = $conn->prepare("INSERT INTO customers (mobile, name, address_json) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), address_json = VALUES(address_json)");
            if ($stmt) {
                $stmt->bind_param("sss", $mobile, $cName, $cAddr);
                $stmt->execute();
            }
        }
    }
    echo json_encode(["success" => true, "role" => "customer", "mobile" => $mobile, "name" => $cName, "address_json" => $cAddr]);
    exit();
} elseif ($action == 'locations' || $action == 'get-locations') {
    $res = $conn->query("SELECT * FROM locations ORDER BY id ASC");
    $locations = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $locations[] = $row;
        }
    }
    echo json_encode(["success" => true, "locations" => $locations]);
    exit();
} elseif ($action == 'add-location') {
    $locName = isset($input['name']) ? trim($input['name']) : (isset($input['location_name']) ? trim($input['location_name']) : '');
    if (!empty($locName)) {
        $stmt = $conn->prepare("INSERT IGNORE INTO locations (name) VALUES (?)");
        if ($stmt) {
            $stmt->bind_param("s", $locName);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Location Saved"]);
    exit();
} elseif ($action == 'create-delivery-boy') {
    $name = isset($input['name']) ? trim($input['name']) : '';
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $vehicle = isset($input['vehicle']) ? trim($input['vehicle']) : 'Bike';
    $location = isset($input['location']) ? trim($input['location']) : '';

    if (!empty($username) && !empty($password) && !empty($name)) {
        $stmt = $conn->prepare("INSERT INTO delivery_boys (name, username, password, mobile, vehicle, location) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name=VALUES(name), password=VALUES(password), mobile=VALUES(mobile), vehicle=VALUES(vehicle), location=VALUES(location)");
        if ($stmt) {
            $stmt->bind_param("ssssss", $name, $username, $password, $mobile, $vehicle, $location);
            if ($stmt->execute()) {
                echo json_encode(["success" => true, "message" => "Delivery Boy Account Created Successfully"]);
                exit();
            }
        }
    }
    echo json_encode(["success" => false, "message" => "Required fields missing or SQL error"]);
    exit();
} elseif ($action == 'update-delivery-boy') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $vehicle = isset($input['vehicle']) ? trim($input['vehicle']) : 'Bike';
    $location = isset($input['location']) ? trim($input['location']) : '';

    if (!empty($username)) {
        $stmt = $conn->prepare("UPDATE delivery_boys SET name = ?, password = ?, mobile = ?, vehicle = ?, location = ? WHERE username = ?");
        if ($stmt) {
            $stmt->bind_param("ssssss", $name, $password, $mobile, $vehicle, $location, $username);
            $stmt->execute();
            echo json_encode(["success" => true, "message" => "Delivery partner updated successfully"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid username"]);
    exit();
} elseif ($action == 'update-delivery-status') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $delivery_status = isset($input['delivery_status']) ? trim($input['delivery_status']) : 'Picked Up';
    $delivered_by = isset($input['delivered_by']) ? trim($input['delivered_by']) : '';
    $time_str = date('d/m/Y, H:i');

    if ($msg_id > 0) {
        $lowerStatus = strtolower($delivery_status);
        if ($lowerStatus == 'picked up' || $lowerStatus == 'picked_up' || $lowerStatus == 'out for delivery') {
            $stmt = $conn->prepare("UPDATE messages SET delivery_status = ?, delivered_by = ?, picked_up_at = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("sssi", $delivery_status, $delivered_by, $time_str, $msg_id);
                $stmt->execute();
            }
        } elseif ($lowerStatus == 'delivered') {
            $stmt = $conn->prepare("UPDATE messages SET delivery_status = 'Delivered', order_status = 'Delivered', delivered_by = ?, delivered_at = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("ssi", $delivered_by, $time_str, $msg_id);
                $stmt->execute();
            }
        } else {
            $stmt = $conn->prepare("UPDATE messages SET delivery_status = ?, delivered_by = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("ssi", $delivery_status, $delivered_by, $msg_id);
                $stmt->execute();
            }
        }
        echo json_encode(["success" => true, "message" => "Delivery status updated in database"]);
        exit();
    }
    echo json_encode(["success" => false, "message" => "Invalid message ID"]);
    exit();
} elseif ($action == 'delivery-boys') {
    $res = $conn->query("SELECT * FROM delivery_boys ORDER BY id DESC");
    $delivery_boys = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $delivery_boys[] = $row;
        }
    }
    echo json_encode(["success" => true, "delivery_boys" => $delivery_boys]);
    exit();
} elseif ($action == 'delete-delivery-boy') {
    $username = isset($input['username']) ? trim($input['username']) : (isset($_GET['username']) ? trim($_GET['username']) : '');
    if (!empty($username)) {
        $stmt = $conn->prepare("DELETE FROM delivery_boys WHERE username = ?");
        if ($stmt) {
            $stmt->bind_param("s", $username);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Delivery Boy Account Deleted"]);
    exit();
} elseif ($action == 'delivery-boy-login') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $stmt = $conn->prepare("SELECT * FROM delivery_boys WHERE username = ? AND password = ?");
    if ($stmt) {
        $stmt->bind_param("ss", $username, $password);
        $stmt->execute();
        $res = $stmt->get_result();
        if ($res && $row = $res->fetch_assoc()) {
            echo json_encode(["success" => true, "delivery_boy" => $row]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid Delivery Boy credentials"]);
    exit();
} elseif ($action == 'create-seller') {
    $name = isset($input['name']) ? trim($input['name']) : '';
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $location = isset($input['location']) ? trim($input['location']) : '';

    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'mobile'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN mobile VARCHAR(15) DEFAULT NULL");
    }

    $colCheckLoc = $conn->query("SHOW COLUMNS FROM sellers LIKE 'location'");
    if (!$colCheckLoc || $colCheckLoc->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN location VARCHAR(255) DEFAULT NULL");
    }

    $stmt = $conn->prepare("INSERT INTO sellers (name, username, password, mobile, location) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name=VALUES(name), password=VALUES(password), mobile=VALUES(mobile), location=VALUES(location)");
    if ($stmt) {
        $stmt->bind_param("sssss", $name, $username, $password, $mobile, $location);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Seller Created"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Seller Exists or SQL Error"]);
} elseif ($action == 'update-seller') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $location = isset($input['location']) ? trim($input['location']) : '';

    if (!empty($username)) {
        $stmt = $conn->prepare("UPDATE sellers SET name = ?, password = ?, mobile = ?, location = ? WHERE username = ?");
        if ($stmt) {
            $stmt->bind_param("sssss", $name, $password, $mobile, $location, $username);
            $stmt->execute();
            echo json_encode(["success" => true, "message" => "Seller updated successfully"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid username"]);
    exit();
} elseif ($action == 'sellers') {
    $result = $conn->query("SELECT * FROM sellers ORDER BY id DESC");
    $sellers = array();
    if ($result && $result !== true) {
        while ($row = $result->fetch_assoc()) {
            $sellers[] = $row;
        }
    }
    echo json_encode(["success" => true, "sellers" => $sellers]);
} elseif ($action == 'get-seller-sliders') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    $escapedSeller = $conn->real_escape_string($seller_username);

    $query = "SELECT * FROM seller_sliders ORDER BY id DESC";
    if (!empty($escapedSeller)) {
        $query = "SELECT * FROM seller_sliders WHERE seller_username = '$escapedSeller' ORDER BY id DESC";
    }

    $res = $conn->query($query);
    $sliders = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $sliders[] = $row;
        }
    }
    echo json_encode(["success" => true, "sliders" => $sliders]);
    exit();
} elseif ($action == 'add-seller-slider') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $tag = isset($input['tag']) ? trim($input['tag']) : 'SPECIAL OFFER 🏷️';
    $title = isset($input['title']) ? trim($input['title']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $bg_image_url = isset($input['bg_image_url']) ? trim($input['bg_image_url']) : '';
    $tag_bg_color = isset($input['tag_bg_color']) ? trim($input['tag_bg_color']) : '#10B981';
    $tag_shape = isset($input['tag_shape']) ? trim($input['tag_shape']) : 'pill';
    $title_color = isset($input['title_color']) ? trim($input['title_color']) : '#FFFFFF';
    $desc_color = isset($input['desc_color']) ? trim($input['desc_color']) : '#E2E8F0';

    if (!empty($seller_username) && !empty($title)) {
        $stmt = $conn->prepare("INSERT INTO seller_sliders (seller_username, tag, title, description, bg_image_url, tag_bg_color, tag_shape, title_color, desc_color) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
        if ($stmt) {
            $stmt->bind_param("sssssssss", $seller_username, $tag, $title, $description, $bg_image_url, $tag_bg_color, $tag_shape, $title_color, $desc_color);
            if ($stmt->execute()) {
                echo json_encode(["success" => true, "message" => "Slider saved permanently in database"]);
                exit();
            }
        }
    }
    echo json_encode(["success" => false, "message" => "Required fields missing or SQL error"]);
    exit();
} elseif ($action == 'update-seller-slider') {
    $slider_id = isset($input['slider_id']) ? (int)$input['slider_id'] : 0;
    $tag = isset($input['tag']) ? trim($input['tag']) : '';
    $title = isset($input['title']) ? trim($input['title']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $bg_image_url = isset($input['bg_image_url']) ? trim($input['bg_image_url']) : '';
    $tag_bg_color = isset($input['tag_bg_color']) ? trim($input['tag_bg_color']) : '#10B981';
    $tag_shape = isset($input['tag_shape']) ? trim($input['tag_shape']) : 'pill';
    $title_color = isset($input['title_color']) ? trim($input['title_color']) : '#FFFFFF';
    $desc_color = isset($input['desc_color']) ? trim($input['desc_color']) : '#E2E8F0';

    if ($slider_id > 0) {
        $stmt = $conn->prepare("UPDATE seller_sliders SET tag = ?, title = ?, description = ?, bg_image_url = ?, tag_bg_color = ?, tag_shape = ?, title_color = ?, desc_color = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssssssssi", $tag, $title, $description, $bg_image_url, $tag_bg_color, $tag_shape, $title_color, $desc_color, $slider_id);
            $stmt->execute();
            echo json_encode(["success" => true, "message" => "Slider updated in database"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid Slider ID"]);
    exit();
} elseif ($action == 'delete-seller-slider') {
    $slider_id = isset($input['slider_id']) ? (int)$input['slider_id'] : (isset($_GET['slider_id']) ? (int)$_GET['slider_id'] : 0);
    if ($slider_id > 0) {
        $conn->query("DELETE FROM seller_sliders WHERE id = $slider_id");
    }
    echo json_encode(["success" => true, "message" => "Slider deleted from database"]);
    exit();
} elseif ($action == 'update-bill-image' || $action == 'save-order-bill-image') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $bill_image = isset($input['bill_image']) ? trim($input['bill_image']) : '';

    $colCheckBill = $conn->query("SHOW COLUMNS FROM messages LIKE 'bill_image'");
    if (!$colCheckBill || $colCheckBill->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN bill_image LONGTEXT DEFAULT NULL");
    }

    if ($msg_id > 0) {
        $stmt = $conn->prepare("UPDATE messages SET bill_image = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("si", $bill_image, $msg_id);
            $stmt->execute();
            echo json_encode(["success" => true, "message" => "Bill photo saved in database"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid Message ID"]);
    exit();
} elseif ($action == 'get-customer-profile') {
    $mobile = isset($_GET['mobile']) ? trim($_GET['mobile']) : (isset($input['mobile']) ? trim($input['mobile']) : '');
    $digits = preg_replace('/[^0-9]/', '', $mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

    $cName = 'Customer';
    $cAddr = '';
    if (!empty($last10)) {
        $res = $conn->query("SELECT name, address_json FROM customers WHERE mobile = '$mobile' OR mobile LIKE '$escapedLike' ORDER BY id DESC LIMIT 1");
        if ($res && $row = $res->fetch_assoc()) {
            $dbName = trim($row['name'] ?? '');
            if (!empty($dbName)) $cName = $dbName;
            if (!empty($row['address_json'])) $cAddr = $row['address_json'];
        }
    }
    echo json_encode(["success" => true, "mobile" => $mobile, "name" => $cName, "address_json" => $cAddr]);
    exit();
} elseif ($action == 'update-customer-profile' || $action == 'save-customer-address') {
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $address_json = isset($input['address_json']) ? (is_array($input['address_json']) ? json_encode($input['address_json']) : trim($input['address_json'])) : '';

    if (!empty($mobile)) {
        $digits = preg_replace('/[^0-9]/', '', $mobile);
        $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;

        if (!empty($address_json) && !empty($name) && $name !== 'Customer') {
            $stmt = $conn->prepare("INSERT INTO customers (mobile, name, address_json) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), address_json = VALUES(address_json)");
            if ($stmt) {
                $stmt->bind_param("sss", $mobile, $name, $address_json);
                $stmt->execute();
            }
        } elseif (!empty($address_json)) {
            $stmt = $conn->prepare("INSERT INTO customers (mobile, address_json) VALUES (?, ?) ON DUPLICATE KEY UPDATE address_json = VALUES(address_json)");
            if ($stmt) {
                $stmt->bind_param("ss", $mobile, $address_json);
                $stmt->execute();
            }
        } elseif (!empty($name) && $name !== 'Customer') {
            $stmt = $conn->prepare("INSERT INTO customers (mobile, name) VALUES (?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name)");
            if ($stmt) {
                $stmt->bind_param("ss", $mobile, $name);
                $stmt->execute();
            }
        }
    }
    echo json_encode(["success" => true, "message" => "Customer profile & address updated in database"]);
    exit();
} elseif ($action == 'search-seller') {
    $rawTerm = isset($_GET['mobile']) ? trim($_GET['mobile']) : (isset($input['mobile']) ? trim($input['mobile']) : '');
    $digits = preg_replace('/[^0-9]/', '', $rawTerm);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;

    $searchLike = "%" . $conn->real_escape_string($rawTerm) . "%";
    $searchDigits = "%" . $conn->real_escape_string($last10) . "%";

    $query = "SELECT * FROM sellers WHERE username LIKE '$searchLike' OR name LIKE '$searchLike'";
    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'mobile'");
    if ($colCheck && $colCheck->num_rows > 0) {
        $query = "SELECT * FROM sellers WHERE username LIKE '$searchLike' OR name LIKE '$searchLike' OR mobile LIKE '$searchDigits' OR mobile LIKE '$searchLike'";
    }

    $res = $conn->query($query);
    $sellers = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $sellers[] = $row;
        }
    }
    echo json_encode(["success" => true, "sellers" => $sellers]);
} elseif ($action == 'send-message') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $customer_mobile = isset($input['customer_mobile']) ? trim($input['customer_mobile']) : '';
    $message = isset($input['message']) ? trim($input['message']) : '';
    $sender_type = isset($input['sender_type']) ? trim($input['sender_type']) : 'customer';

    if (empty($seller_username) || empty($customer_mobile) || empty($message)) {
        echo json_encode(["success" => false, "message" => "Required fields missing"]);
        exit();
    }

    $items = array();
    $lines = explode("\n", $message);
    foreach ($lines as $line) {
        $trimmed = trim($line);
        if (!empty($trimmed)) {
            $items[] = array("text" => $trimmed, "status" => 0);
        }
    }
    $items_json = json_encode($items);

    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

    $seqCount = 1;
    $numRes = $conn->query("SELECT COUNT(*) as total FROM messages WHERE seller_username = '$escapedSeller' AND customer_mobile LIKE '$escapedLike'");
    if ($numRes && $nRow = $numRes->fetch_assoc()) {
        $seqCount = (int)$nRow['total'] + 1;
    }
    $order_id = "Order #" . $seqCount;
    $order_status = "Status";
    $logs_json = json_encode(array());

    $colCheck = $conn->query("SHOW COLUMNS FROM messages LIKE 'logs_json'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN logs_json TEXT DEFAULT NULL");
    }

    $stmt = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, items_json, order_id, order_status, logs_json, sender_type, is_read, payment_status, delivery_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 'unpaid', 'pending')");
    if ($stmt) {
        $stmt->bind_param("ssssssss", $seller_username, $customer_mobile, $message, $items_json, $order_id, $order_status, $logs_json, $sender_type);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Message sent"]);
            exit();
        }
    }

    $stmtFallback = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, sender_type, is_read, payment_status, delivery_status) VALUES (?, ?, ?, ?, 0, 'unpaid', 'pending')");
    if ($stmtFallback) {
        $stmtFallback->bind_param("ssss", $seller_username, $customer_mobile, $message, $sender_type);
        if ($stmtFallback->execute()) {
            echo json_encode(["success" => true, "message" => "Message sent (fallback)"]);
            exit();
        }
    }

    echo json_encode(["success" => false, "message" => "SQL Error"]);
} elseif ($action == 'update-item-status') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $items = isset($input['items']) ? $input['items'] : array();
    $items_json = json_encode($items);

    $seller_name = isset($input['seller_name']) ? trim($input['seller_name']) : 'SELLER';
    $item_num = isset($input['item_num']) ? (int)$input['item_num'] : 1;
    $status = isset($input['status']) ? (int)$input['status'] : 1;
    $time_str = date('d/m/Y, H:i');

    $colCheck = $conn->query("SHOW COLUMNS FROM messages LIKE 'logs_json'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN logs_json TEXT DEFAULT NULL");
    }

    $existing_logs = array();
    if ($msg_id > 0) {
        $res = $conn->query("SELECT logs_json FROM messages WHERE id = $msg_id");
        if ($res && $row = $res->fetch_assoc()) {
            if (!empty($row['logs_json'])) {
                $decoded = json_decode($row['logs_json'], true);
                if (is_array($decoded)) $existing_logs = $decoded;
            }
        }

        if ($status == 1 || $status == 2) {
            array_unshift($existing_logs, array(
                "item_num" => $item_num,
                "status" => $status,
                "seller_name" => strtoupper($seller_name),
                "timestamp" => $time_str
            ));
        }

        $logs_json = json_encode($existing_logs);
        $stmt = $conn->prepare("UPDATE messages SET items_json = ?, logs_json = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssi", $items_json, $logs_json, $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "logs" => $existing_logs]);
} elseif ($action == 'update-order-status') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $status_text = isset($input['order_status']) ? trim($input['order_status']) : 'Ready';
    $cancelled_at = isset($input['cancelled_at']) ? trim($input['cancelled_at']) : date('d/m/Y, H:i');
    $cancel_reason = isset($input['cancel_reason']) ? trim($input['cancel_reason']) : '';

    if ($msg_id > 0) {
        if (!empty($cancel_reason) || strtolower($status_text) == 'cancelled') {
            $stmt = $conn->prepare("UPDATE messages SET order_status = 'Cancelled', delivery_status = 'Cancelled', cancelled_at = ?, cancel_reason = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("ssi", $cancelled_at, $cancel_reason, $msg_id);
                $stmt->execute();
            }
        } else {
            $stmt = $conn->prepare("UPDATE messages SET order_status = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("si", $status_text, $msg_id);
                $stmt->execute();
            }
        }
    }
    echo json_encode(["success" => true]);
    exit();
} elseif ($action == 'update-order-amount') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $amount = isset($input['order_amount']) ? (float)$input['order_amount'] : (isset($input['amount']) ? (float)$input['amount'] : 0.0);

    $colCheckAmt = $conn->query("SHOW COLUMNS FROM messages LIKE 'order_amount'");
    if (!$colCheckAmt || $colCheckAmt->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN order_amount DECIMAL(10,2) DEFAULT 0.00");
    }

    if ($msg_id > 0) {
        $stmt = $conn->prepare("UPDATE messages SET order_amount = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("di", $amount, $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "order_amount" => $amount]);
    exit();
} elseif ($action == 'update-order-payment-status') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $payment_status = isset($input['payment_status']) ? trim($input['payment_status']) : 'paid';
    $payment_utr = isset($input['payment_utr']) ? trim($input['payment_utr']) : '';
    $paid_amount = isset($input['paid_amount']) ? (float)$input['paid_amount'] : (isset($input['amount']) ? (float)$input['amount'] : 0.0);
    $paid_at = isset($input['paid_at']) ? trim($input['paid_at']) : date('d/m/Y, H:i');

    if ($msg_id > 0) {
        $stmt = $conn->prepare("UPDATE messages SET payment_status = ?, payment_utr = ?, paid_amount = ?, paid_at = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssdsi", $payment_status, $payment_utr, $paid_amount, $paid_at, $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Payment status saved in database"]);
    exit();
} elseif ($action == 'delete-message') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : (isset($_GET['message_id']) ? (int)$_GET['message_id'] : 0);
    if ($msg_id > 0) {
        $stmt = $conn->prepare("DELETE FROM messages WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("i", $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true]);
} elseif ($action == 'mark-read') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '';
    $customer_mobile = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : '';
    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $searchLike = "%" . $last10 . "%";

    if (!empty($seller_username) && !empty($customer_mobile)) {
        $stmt = $conn->prepare("UPDATE messages SET is_read = 1 WHERE seller_username = ? AND customer_mobile LIKE ?");
        if ($stmt) {
            $stmt->bind_param("ss", $seller_username, $searchLike);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true]);
} elseif ($action == 'get-seller-conversations') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '';
    if (empty($seller_username)) {
        echo json_encode(["success" => false, "conversations" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $query = "SELECT * FROM messages WHERE seller_username = '$escapedSeller' ORDER BY id DESC";
    $res = $conn->query($query);
    $conversations = array();
    $seenCust = array();

    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $c = $row['customer_mobile'];
            if (!in_array($c, $seenCust)) {
                $seenCust[] = $c;

                $unreadCount = 0;
                $countRes = $conn->query("SELECT COUNT(*) as cnt FROM messages WHERE seller_username = '$escapedSeller' AND customer_mobile = '$c' AND sender_type = 'customer' AND (is_read = 0 OR is_read IS NULL)");
                if ($countRes && $cntRow = $countRes->fetch_assoc()) {
                    $unreadCount = (int)$cntRow['cnt'];
                }

                $cDigits = preg_replace('/[^0-9]/', '', $c);
                $cLast10 = (strlen($cDigits) >= 10) ? substr($cDigits, -10) : $cDigits;
                $cEscapedLike = "%" . $conn->real_escape_string($cLast10) . "%";

                $cName = "Customer ($c)";
                $custRes = $conn->query("SELECT name FROM customers WHERE mobile = '$c' OR mobile LIKE '$cEscapedLike' ORDER BY id DESC LIMIT 1");
                if ($custRes && $custRow = $custRes->fetch_assoc()) {
                    $dbName = trim($custRow['name']);
                    if (!empty($dbName) && $dbName !== 'Customer' && strpos($dbName, 'Customer') !== 0) {
                        $cName = $dbName;
                    }
                }

                $conversations[] = array(
                    "customer_mobile" => $c,
                    "customer_name" => $cName,
                    "name" => $cName,
                    "last_message" => isset($row['message']) ? $row['message'] : '',
                    "last_time" => isset($row['created_at']) ? $row['created_at'] : '',
                    "unread_count" => $unreadCount
                );
            }
        }
    }
    echo json_encode(["success" => true, "conversations" => $conversations]);
} elseif ($action == 'get-customer-conversations') {
    $customer_mobile = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : '';
    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;

    if (empty($last10)) {
        echo json_encode(["success" => true, "conversations" => array()]);
        exit();
    }

    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";
    $query = "SELECT * FROM messages WHERE customer_mobile LIKE '$escapedLike' ORDER BY id DESC";
    $res = $conn->query($query);
    $conversations = array();
    $seenSellers = array();

    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $u = $row['seller_username'];
            if (!in_array($u, $seenSellers)) {
                $seenSellers[] = $u;

                $sName = $u;
                $sMobile = '';
                $sRes = $conn->query("SELECT * FROM sellers WHERE username = '$u' OR name = '$u' LIMIT 1");
                if ($sRes && $sRow = $sRes->fetch_assoc()) {
                    if (isset($sRow['name']) && !empty($sRow['name'])) $sName = $sRow['name'];
                    if (isset($sRow['mobile']) && !empty($sRow['mobile'])) $sMobile = $sRow['mobile'];
                }

                $conversations[] = array(
                    "seller_username" => $u,
                    "seller_name" => $sName,
                    "seller_mobile" => $sMobile,
                    "last_message" => isset($row['message']) ? $row['message'] : '',
                    "last_time" => isset($row['created_at']) ? $row['created_at'] : ''
                );
            }
        }
    }

    echo json_encode(["success" => true, "conversations" => $conversations]);
} elseif ($action == 'get-messages') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '';
    $customer_mobile = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : '';
    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $searchLike = "%" . $last10 . "%";

    if (!empty($seller_username) && !empty($last10)) {
        $stmt = $conn->prepare("SELECT * FROM messages WHERE seller_username = ? AND customer_mobile LIKE ? ORDER BY id ASC");
        if ($stmt) {
            $stmt->bind_param("ss", $seller_username, $searchLike);
            $stmt->execute();
            $res = $stmt->get_result();
            $messages = array();
            if ($res) {
                while ($row = $res->fetch_assoc()) {
                    $messages[] = $row;
                }
            }
            echo json_encode(["success" => true, "messages" => $messages]);
            exit();
        }
    }
    echo json_encode(["success" => false, "messages" => array()]);
} elseif ($action == 'delete-seller') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $stmt = $conn->prepare("DELETE FROM sellers WHERE username = ?");
    if ($stmt) {
        $stmt->bind_param("s", $username);
        $stmt->execute();
    }
    echo json_encode(["success" => true, "message" => "Seller Deleted"]);
} elseif ($action == 'seller-login') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $stmt = $conn->prepare("SELECT * FROM sellers WHERE username = ? AND password = ?");
    if ($stmt) {
        $stmt->bind_param("ss", $username, $password);
        $stmt->execute();
        $res = $stmt->get_result();
        if ($res && $row = $res->fetch_assoc()) {
            echo json_encode(["success" => true, "seller" => $row]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid credentials"]);
} elseif ($action == 'add-seller-product') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $unit = isset($input['unit']) ? trim($input['unit']) : 'Pcs';
    $category = isset($input['category']) ? trim($input['category']) : '';
    $qty = isset($input['qty']) ? (int)$input['qty'] : 1;
    if ($qty <= 0) $qty = 1;
    $rate = isset($input['rate']) ? (float)$input['rate'] : 0.0;

    if (empty($seller_username) || empty($name)) {
        echo json_encode(["success" => false, "message" => "Seller username and product name are required"]);
        exit();
    }

    $colCheckCat = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'category'");
    $image_url = isset($input['image_url']) ? trim($input['image_url']) : (isset($input['image']) ? trim($input['image']) : '');

    $colCheckProdImg = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'image_url'");
    if (!$colCheckProdImg || $colCheckProdImg->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN image_url LONGTEXT DEFAULT NULL");
    }

    $stmt = $conn->prepare("INSERT INTO seller_products (seller_username, name, description, unit, category, qty, rate, image_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("sssssids", $seller_username, $name, $description, $unit, $category, $qty, $rate, $image_url);
        if ($stmt->execute()) {
            $newId = $stmt->insert_id;
            echo json_encode([
                "success" => true,
                "message" => "Product added successfully",
                "product" => [
                    "id" => $newId,
                    "seller_username" => $seller_username,
                    "name" => $name,
                    "description" => $description,
                    "unit" => $unit,
                    "category" => $category,
                    "qty" => $qty,
                    "rate" => $rate,
                    "image_url" => $image_url
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add product"]);
    exit();
} elseif ($action == 'get-seller-products') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username)) {
        echo json_encode(["success" => true, "products" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $res = $conn->query("SELECT * FROM seller_products WHERE seller_username = '$escapedSeller' ORDER BY id DESC");
    $products = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $row['qty'] = isset($row['qty']) ? (int)$row['qty'] : 1;
            $row['rate'] = (float)$row['rate'];
            $row['image_url'] = isset($row['image_url']) ? $row['image_url'] : (isset($row['image']) ? $row['image'] : '');
            $products[] = $row;
        }
    }
    echo json_encode(["success" => true, "products" => $products]);
    exit();
} elseif ($action == 'update-seller-product') {
    $id = isset($input['id']) ? (int)$input['id'] : 0;
    $name = isset($input['name']) ? trim($input['name']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $unit = isset($input['unit']) ? trim($input['unit']) : 'Pcs';
    $category = isset($input['category']) ? trim($input['category']) : '';
    $qty = isset($input['qty']) ? (int)$input['qty'] : 1;
    if ($qty <= 0) $qty = 1;
    $rate = isset($input['rate']) ? (float)$input['rate'] : 0.0;
    $image_url = isset($input['image_url']) ? trim($input['image_url']) : (isset($input['image']) ? trim($input['image']) : '');

    if ($id <= 0 || empty($name)) {
        echo json_encode(["success" => false, "message" => "Product ID and name required"]);
        exit();
    }

    $stmt = $conn->prepare("UPDATE seller_products SET name = ?, description = ?, unit = ?, category = ?, qty = ?, rate = ?, image_url = ? WHERE id = ?");
    if ($stmt) {
        $stmt->bind_param("ssssidsi", $name, $description, $unit, $category, $qty, $rate, $image_url, $id);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Product updated successfully"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to update product"]);
    exit();
} elseif ($action == 'delete-seller-product') {
    $id = isset($input['id']) ? (int)$input['id'] : (isset($_GET['id']) ? (int)$_GET['id'] : 0);
    if ($id > 0) {
        $stmt = $conn->prepare("DELETE FROM seller_products WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("i", $id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Product deleted"]);
    exit();
} elseif ($action == 'get-seller-units') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username)) {
        echo json_encode(["success" => true, "units" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $res = $conn->query("SELECT * FROM seller_units WHERE seller_username = '$escapedSeller' ORDER BY id ASC");
    $units = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $units[] = $row;
        }
    }
    echo json_encode(["success" => true, "units" => $units]);
    exit();
} elseif ($action == 'add-seller-unit') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($_POST['seller_username']) ? trim($_POST['seller_username']) : ''));
    $unit_name = isset($input['unit_name']) ? trim($input['unit_name']) : (isset($_GET['unit_name']) ? trim($_GET['unit_name']) : (isset($_POST['unit_name']) ? trim($_POST['unit_name']) : ''));

    if (empty($seller_username) || empty($unit_name)) {
        echo json_encode(["success" => false, "message" => "Seller username and unit name required"]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedUnit = $conn->real_escape_string($unit_name);
    $chk = $conn->query("SELECT id FROM seller_units WHERE seller_username = '$escapedSeller' AND unit_name = '$escapedUnit' LIMIT 1");
    if ($chk && $row = $chk->fetch_assoc()) {
        echo json_encode([
            "success" => true,
            "message" => "Unit already exists",
            "unit" => [
                "id" => (int)$row['id'],
                "seller_username" => $seller_username,
                "unit_name" => $unit_name
            ]
        ]);
        exit();
    }

    $stmt = $conn->prepare("INSERT INTO seller_units (seller_username, unit_name) VALUES (?, ?)");
    if ($stmt) {
        $stmt->bind_param("ss", $seller_username, $unit_name);
        if ($stmt->execute()) {
            $newId = $stmt->insert_id;
            echo json_encode([
                "success" => true,
                "message" => "Unit added",
                "unit" => [
                    "id" => $newId,
                    "seller_username" => $seller_username,
                    "unit_name" => $unit_name
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add unit"]);
    exit();
} elseif ($action == 'update-seller-unit') {
    $id = isset($input['id']) ? (int)$input['id'] : 0;
    $unit_name = isset($input['unit_name']) ? trim($input['unit_name']) : '';

    if ($id <= 0 || empty($unit_name)) {
        echo json_encode(["success" => false, "message" => "Unit ID and name required"]);
        exit();
    }

    $stmt = $conn->prepare("UPDATE seller_units SET unit_name = ? WHERE id = ?");
    if ($stmt) {
        $stmt->bind_param("si", $unit_name, $id);
        $stmt->execute();
    }
    echo json_encode(["success" => true, "message" => "Unit updated"]);
    exit();
} elseif ($action == 'delete-seller-unit') {
    $id = isset($input['id']) ? (int)$input['id'] : (isset($_GET['id']) ? (int)$_GET['id'] : 0);
    if ($id > 0) {
        $stmt = $conn->prepare("DELETE FROM seller_units WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("i", $id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Unit deleted"]);
    exit();
} elseif ($action == 'get-seller-categories') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username)) {
        echo json_encode(["success" => true, "categories" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $res = $conn->query("SELECT * FROM seller_categories WHERE seller_username = '$escapedSeller' ORDER BY id ASC");
    $categories = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $categories[] = $row;
        }
    }
    echo json_encode(["success" => true, "categories" => $categories]);
    exit();
} elseif ($action == 'add-seller-category') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $image_url = isset($input['image_url']) ? trim($input['image_url']) : '';
    $color = isset($input['color']) ? trim($input['color']) : '#8B5CF6';

    if (empty($seller_username) || empty($name)) {
        echo json_encode(["success" => false, "message" => "Seller username and category name required"]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedName = $conn->real_escape_string($name);
    $chk = $conn->query("SELECT id, image_url, color FROM seller_categories WHERE seller_username = '$escapedSeller' AND name = '$escapedName' LIMIT 1");
    if ($chk && $row = $chk->fetch_assoc()) {
        echo json_encode([
            "success" => true,
            "message" => "Category already exists",
            "category" => [
                "id" => (int)$row['id'],
                "seller_username" => $seller_username,
                "name" => $name,
                "image_url" => $row['image_url'],
                "color" => !empty($row['color']) ? $row['color'] : '#8B5CF6'
            ]
        ]);
        exit();
    }

    $stmt = $conn->prepare("INSERT INTO seller_categories (seller_username, name, image_url, color) VALUES (?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssss", $seller_username, $name, $image_url, $color);
        if ($stmt->execute()) {
            $newId = $stmt->insert_id;
            echo json_encode([
                "success" => true,
                "message" => "Category added",
                "category" => [
                    "id" => $newId,
                    "seller_username" => $seller_username,
                    "name" => $name,
                    "image_url" => $image_url,
                    "color" => $color
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add category"]);
    exit();
} elseif ($action == 'update-seller-category') {
    $id = isset($input['id']) ? (int)$input['id'] : 0;
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $image_url = isset($input['image_url']) ? trim($input['image_url']) : '';
    $color = isset($input['color']) ? trim($input['color']) : '#8B5CF6';

    if ($id <= 0 || empty($name)) {
        echo json_encode(["success" => false, "message" => "Category ID and name required"]);
        exit();
    }

    if (!empty($image_url)) {
        $stmt = $conn->prepare("UPDATE seller_categories SET name = ?, image_url = ?, color = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("sssi", $name, $image_url, $color, $id);
            $stmt->execute();
        }
    } else {
        $stmt = $conn->prepare("UPDATE seller_categories SET name = ?, color = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssi", $name, $color, $id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Category updated"]);
    exit();
} elseif ($action == 'delete-seller-category') {
    $id = isset($input['id']) ? (int)$input['id'] : (isset($_GET['id']) ? (int)$_GET['id'] : 0);
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';

    if ($id > 0) {
        $stmt = $conn->prepare("DELETE FROM seller_categories WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("i", $id);
            $stmt->execute();
        }
    } elseif (!empty($seller_username) && !empty($name)) {
        $stmt = $conn->prepare("DELETE FROM seller_categories WHERE seller_username = ? AND name = ?");
        if ($stmt) {
            $stmt->bind_param("ss", $seller_username, $name);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Category deleted"]);
    exit();
} else {
    echo json_encode(["success" => true, "message" => "Daily Mart API Active"]);
}

$conn->close();
?>
