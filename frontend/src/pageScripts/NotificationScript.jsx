import React from 'react';

import { useEffect, useState } from 'react';
import { getUserNotifications } from "../api/UserService";
import { accessToken, getCurrentUserProfile } from '../api/spotify';
import { catchErrors } from '../utils';

import { userContext } from '../api/userContext'
import { useContext } from 'react';

import NotificationView from "../pages/NotificationView";
import NotificationCard from "../components/notification/NotificationCard";

const NotificationCardScript = () => {

    const id = useContext(userContext).id;
    const [notifications, setNotifications] = useState([]);

    useEffect(() => {
        const fetchData = async () => {
            const response = await getUserNotifications(id);
            const data = await response.json();
            setNotifications(data);
            console.log(id);
            console.log(data);
        };
        catchErrors(fetchData());
    }, []);

    
    const removeNotification = (id) =>{
        let newNotifications = notifications.filter((notification) => notification._id !== id)
        setNotifications(newNotifications)
    }

    console.log(notifications);

    return (
        <>
            <NotificationView notifications={notifications} onClick={removeNotification}/>
            {/* <div className="container align-items-center Oswald_regular">
                {notifications.map(notification => (
                    <NotificationCard.ArtistsEvent key={notification._id} img={"notification.img"} artistName={notification.associatedArtists[0]} 
                    friendName={notification.associatedUsers[0]} 
                    onClick={() => removeNotification(notification._id)} 
                    />
                ))}
            </div> */}
        </>
    );
}

export default NotificationCardScript;