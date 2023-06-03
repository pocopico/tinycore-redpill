<?php
//error_reporting(0);

$target_dir = "files/";
$target_file = $target_dir . basename($_FILES["fileToUpload"]["name"]);
$uploadOk = 1;

// Check if file already exists
if (file_exists($target_file)) {
  echo "Sorry, file already exists.";
  $uploadOk = 0;
}

// Check file size
if ($_FILES["fileToUpload"]["size"] > 500000000) {
  echo "Sorry, your file is too large :" . $_FILES["fileToUpload"]["size"];
  $uploadOk = 0;
}

// Check if $uploadOk is set to 0 by an error
if ($uploadOk == 0) {
  echo "Sorry, your file was not uploaded.";
} else {
  // Try to upload the file
  if (move_uploaded_file($_FILES["fileToUpload"]["tmp_name"], $target_file)) {
    // Redirect to index.html
    header("Location: index.sh?action=filemanagement");
    exit;
  } else {
    echo "Sorry, there was an error uploading your file.";
  }
}
#phpinfo();
?>
