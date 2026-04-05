// Sample JavaScript file for testing ATS caching

console.log('ATS Cluster Demo - Static Asset Loaded');

// Simple function to test cache behavior
function testCacheHeaders() {
    fetch(window.location.href)
        .then(response => {
            console.log('Cache Headers:');
            console.log('X-Cache:', response.headers.get('X-Cache'));
            console.log('Age:', response.headers.get('Age'));
            console.log('Via:', response.headers.get('Via'));
            console.log('X-Origin-Server:', response.headers.get('X-Origin-Server'));
            console.log('X-Backend-Server:', response.headers.get('X-Backend-Server'));
        })
        .catch(err => console.error('Error:', err));
}

// Function to demonstrate consistent hashing
async function testConsistentHashing() {
    const urls = ['/page1', '/page2', '/page3', '/page4', '/page5'];
    const results = {};

    for (const url of urls) {
        const response = await fetch(url);
        const via = response.headers.get('Via');
        const atsNode = via ? via.match(/ats-\d/)?.[0] : 'unknown';
        results[url] = atsNode;
    }

    console.log('Consistent Hashing Test Results:');
    console.table(results);
    console.log('Same URL should always hit the same ATS node!');
}

// Make functions available globally
window.testCacheHeaders = testCacheHeaders;
window.testConsistentHashing = testConsistentHashing;

// This file should be cached for 1 year by ATS
// Test with: curl -I http://localhost/static/app.js
