import React from "react";
import {
    BrowserRouter,
    Routes,
    Route,
} from 'react-router-dom';

import MainConcert from './components/concerts/MainConcert';
import ListeningHistory from './pages/ListeningHistory';
import Settings from './pages/Settings';
/**
 * This AppRouter allows us to navigate across the application and works with our
 * navbar for sending users to different pages/components. 
 * @returns Router components that defines the different paths in our application
 */
function AppRouter() {

    return (
        <BrowserRouter>
        <Routes>
            <Route path = "/" element = {
                <ListeningHistory />
            } />
            <Route path = "/concerts/" element = {
                <MainConcert />
            } />
            <Route path = "/settings/" element = {
                <Settings />
            } />
        </Routes>
        </BrowserRouter>
    )
}

export default AppRouter