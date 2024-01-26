import os
import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from urllib.parse import urljoin, unquote
import time

# Configure Selenium to run headless
options = Options()
options.headless = True
options.add_argument("--window-size=1920,1200")

# Function to initialize the WebDriver
def create_webdriver_instance():
    driver = webdriver.Chrome(options=options)
    return driver

# Function to download and save PDF
def download_pdf(pdf_url, session, folder='pdf', referer_url=None):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
        'Referer': referer_url or pdf_url
    }
    try:
        if not os.path.exists(folder):
            os.makedirs(folder)
        decoded_url = unquote(pdf_url)
        local_filename = decoded_url.split('/')[-1]
        with session.get(pdf_url, stream=True, headers=headers) as r:
            if r.status_code == 200:
                with open(os.path.join(folder, local_filename), 'wb') as f:
                    for chunk in r.iter_content(chunk_size=8192):
                        f.write(chunk)
                print(f"Downloaded {pdf_url}")
            else:
                print(f"Failed to download {pdf_url}: Status code {r.status_code}")
    except Exception as e:
        print(f"Error downloading {pdf_url}: {e}")

# Function to get sub-pages from the base URL
def get_sub_pages(driver, base_url):
    sub_pages = set()
    try:
        driver.get(base_url)
        WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.TAG_NAME, "body")))
        elements = driver.find_elements(By.TAG_NAME, "a")
        for element in elements:
            href = element.get_attribute('href')
            if href and "document-center" in href:
                sub_pages.add(href)
    except Exception as e:
        print(f"Error getting sub-pages: {e}")
    return list(sub_pages)

# Function to scrape a single page for PDFs
def scrape_page(driver, session, url):
    try:
        driver.get(url)
        WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.TAG_NAME, "body")))
        pdf_links = driver.find_elements(By.XPATH, "//a[contains(@href, '.pdf')]")
        for link in pdf_links:
            pdf_url = urljoin(url, link.get_attribute('href'))
            download_pdf(pdf_url, session, referer_url=url)
            time.sleep(1)  # Delay to avoid rate-limiting
    except Exception as e:
        print(f"Error scraping {url}: {e}")

# Function to recursively or iteratively navigate sub-pages and scrape PDFs
def navigate_and_scrape(driver, session, url, visited=set()):
    if url in visited:
        return
    visited.add(url)
    scrape_page(driver, session, url)
    sub_pages = get_sub_pages(driver, url)
    for sub_page in sub_pages:
        navigate_and_scrape(driver, session, sub_page, visited)

# Main function to start the scraper
def main(base_url):
    try:
        session = requests.Session()
        session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3'
        })
        # Get initial cookies
        response = session.get(base_url)
        driver = create_webdriver_instance()
        # Navigate to the base URL with Selenium before setting cookies
        driver.get(base_url)
        # Add cookies to Selenium WebDriver
        for cookie in session.cookies:
            # Convert requests.cookies.Cookie object to a dictionary
            cookie_dict = {
                'name': cookie.name,
                'value': cookie.value,
                'path': cookie.path,
                'secure': cookie.secure,
                'httpOnly': cookie.has_nonstandard_attr('httpOnly'),
                'expiry': getattr(cookie, 'expires', None)
            }
            # The domain must match the domain of the current page in the driver
            if 'domain' in cookie_dict and cookie_dict['domain'] is not None:
                cookie_dict['domain'] = cookie_dict['domain'].strip('.')
            # Add the cookie to the driver
            driver.add_cookie(cookie_dict)
        navigate_and_scrape(driver, session, base_url)
        driver.quit()
        session.close()
    except Exception as e:
        print(f"Error in main function: {e}")

if __name__ == "__main__":
    base_url = 'https://www.mitel.com/document-center'
    print(f"Starting scraper for {base_url}")
    main(base_url)